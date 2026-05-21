'use strict';

module.exports = async function matchRoutes(fastify) {
  // GET /match/sparks — Daily 7
  fastify.get('/sparks', {
    onRequest: [fastify.authenticate],
    config: {
      rateLimit: { max: 10, timeWindow: '1 hour' },
    },
  }, async (req, reply) => {
    const userId = req.user.uid;

    // Check cache
    const cacheKey = `sparks:${userId}:${new Date().toDateString()}`;
    const cached = await fastify.redis.get(cacheKey);
    if (cached) {
      return fastify.sendSuccess(reply, JSON.parse(cached));
    }

    // Get user's profile for matching
    const userProfile = await fastify.db.query(`
      SELECT p.*, u.gender, u.age, u.city, u.is_premium
      FROM profiles p
      JOIN users u ON u.id = p.user_id
      WHERE p.user_id = $1
    `, [userId]);

    if (!userProfile.rows[0]) {
      return fastify.sendError(reply, 'Profile not found', 404);
    }

    const me = userProfile.rows[0];

    // Get already-seen profiles from past 30 days
    const seenResult = await fastify.db.query(`
      SELECT target_user_id FROM sparks_delivered
      WHERE user_id = $1 AND delivered_at > NOW() - INTERVAL '30 days'
    `, [userId]);

    const seenIds = seenResult.rows.map(r => r.target_user_id);
    const excludeIds = [...seenIds, userId];

    // Get blocked users
    const blockedResult = await fastify.db.query(`
      SELECT blocked_id FROM blocks WHERE blocker_id = $1
      UNION
      SELECT blocker_id FROM blocks WHERE blocked_id = $1
    `, [userId]);

    const blockedIds = blockedResult.rows.map(r => r.blocked_id);
    const allExcludeIds = [...new Set([...excludeIds, ...blockedIds])];

    // Gender filter (heterosexual default, preference-based in full version)
    const genderFilter = me.gender === 'woman' ? 'man' : 'woman';

    // Fetch candidates (top 50 by trust score + last active)
    const candidatesResult = await fastify.db.query(`
      SELECT 
        p.user_id, p.display_name, p.trust_score, p.personality_tags,
        p.voice_intro_url, p.photos_blurred, p.photo_urls, p.prompt_responses,
        u.age, u.city, u.gender, u.verification_level,
        CASE WHEN u.verification_level >= 3 THEN true ELSE false END as is_verified
      FROM profiles p
      JOIN users u ON u.id = p.user_id
      WHERE 
        u.id != ALL($1::uuid[])
        AND u.gender = $2
        AND u.age BETWEEN $3 AND $4
        AND p.is_searchable = true
        AND u.account_status = 'active'
        AND u.last_active > NOW() - INTERVAL '7 days'
        AND ($5 = 'woman' AND p.trust_score >= 70 OR $5 != 'woman')
      ORDER BY p.trust_score DESC, u.last_active DESC
      LIMIT 50
    `, [allExcludeIds, genderFilter, me.age - 5, me.age + 7, me.gender]);

    const candidates = candidatesResult.rows;

    // Score each candidate
    const myTags = new Set(me.personality_tags || []);
    const scored = candidates.map(c => {
      const theirTags = new Set(c.personality_tags || []);
      const tagOverlap = [...myTags].filter(t => theirTags.has(t)).length;
      const tagScore = tagOverlap / Math.max(myTags.size + theirTags.size, 1);

      const trustScore = c.trust_score / 100;
      const cityBonus = c.city === me.city ? 0.1 : 0;
      const verifiedBonus = c.is_verified ? 0.05 : 0;

      const total = (tagScore * 0.4) + (trustScore * 0.35) + cityBonus + verifiedBonus;
      const compatibilityPct = Math.round(Math.min(total * 100 + 30, 99));

      return { ...c, compatibility_score: compatibilityPct, _score: total };
    });

    // Sort and take top 7
    scored.sort((a, b) => b._score - a._score);
    const top7 = scored.slice(0, 7).map(({ _score, photo_urls, ...rest }) => ({
      ...rest,
      profile_photo_url: photo_urls?.[0] || null,
      interests: rest.personality_tags || [],
      shared_interests: [],
      shared_rooms_count: 0,
      voice_duration_seconds: 32,
    }));

    // Cache for 24h
    await fastify.redis.setEx(cacheKey, 86400, JSON.stringify(top7));

    // Log delivered
    if (top7.length > 0) {
      const values = top7.map((_, i) =>
        `($1, $${i * 2 + 2}, NOW(), $${i * 2 + 3})`
      ).join(', ');
      const params = [userId, ...top7.flatMap((s, i) => [s.user_id, i + 1])];
      await fastify.db.query(
        `INSERT INTO sparks_delivered (user_id, target_user_id, delivered_at, rank_position)
         VALUES ${values} ON CONFLICT DO NOTHING`,
        params
      );
    }

    return fastify.sendSuccess(reply, top7, { count: top7.length });
  });

  // POST /match/connect
  fastify.post('/connect', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['target_user_id'],
        properties: { target_user_id: { type: 'string', format: 'uuid' } },
      },
    },
  }, async (req, reply) => {
    const { target_user_id } = req.body;
    const userId = req.user.uid;

    // Update spark action
    await fastify.db.query(`
      UPDATE sparks_delivered SET action = 'connect', action_at = NOW()
      WHERE user_id = $1 AND target_user_id = $2
    `, [userId, target_user_id]);

    // Check if mutual
    const mutualResult = await fastify.db.query(`
      SELECT id FROM sparks_delivered
      WHERE user_id = $1 AND target_user_id = $2 AND action = 'connect'
    `, [target_user_id, userId]);

    let conversationId = null;
    let isMutual = false;

    if (mutualResult.rows.length > 0) {
      isMutual = true;

      // Create connection
      const [a, b] = [userId, target_user_id].sort();
      const connResult = await fastify.db.query(`
        INSERT INTO connections (id, user_a, user_b, status, stage, initiated_by, connected_at)
        VALUES ($1, $2, $3, 'connected', 1, $4, NOW())
        ON CONFLICT (user_a, user_b) DO UPDATE SET status = 'connected', connected_at = NOW()
        RETURNING id
      `, [require('crypto').randomUUID(), a, b, userId]);

      conversationId = connResult.rows[0].id;

      // Notify target user via FCM
      await fastify.redis.publish('notifications', JSON.stringify({
        type: 'mutual_connect',
        target_user_id,
        data: { from_user_id: userId, conversation_id: conversationId },
      }));
    }

    return fastify.sendSuccess(reply, { is_mutual: isMutual, conversation_id: conversationId });
  });

  // POST /match/pass
  fastify.post('/pass', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['target_user_id'],
        properties: { target_user_id: { type: 'string', format: 'uuid' } },
      },
    },
  }, async (req, reply) => {
    const { target_user_id } = req.body;
    await fastify.db.query(`
      UPDATE sparks_delivered SET action = 'pass', action_at = NOW()
      WHERE user_id = $1 AND target_user_id = $2
    `, [req.user.uid, target_user_id]);

    return fastify.sendSuccess(reply, { passed: true });
  });
};
