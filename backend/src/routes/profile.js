'use strict';
const { v4: uuidv4 } = require('uuid');

module.exports = async function profileRoutes(fastify) {
  // GET /profile — get my profile
  fastify.get('/', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const result = await fastify.db.query(`
      SELECT p.*, u.gender, u.age, u.city, u.is_premium, u.premium_tier,
             u.verification_level, u.is_onboarded
      FROM profiles p
      JOIN users u ON u.id = p.user_id
      WHERE p.user_id = $1
    `, [req.user.uid]);

    if (!result.rows[0]) return fastify.sendError(reply, 'Profile not found', 404);
    return fastify.sendSuccess(reply, result.rows[0]);
  });

  // GET /profile/:userId — get another user's public profile
  fastify.get('/:userId', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { userId } = req.params;
    const result = await fastify.db.query(`
      SELECT p.user_id, p.display_name, p.bio_prompt_responses, p.personality_tags,
             p.voice_intro_url, p.intent, p.trust_score, p.profile_completeness,
             p.photos_blurred, p.photo_urls, p.prompt_responses,
             u.age, u.city, u.gender, u.verification_level, u.is_premium
      FROM profiles p
      JOIN users u ON u.id = p.user_id
      WHERE p.user_id = $1 AND p.is_searchable = true AND u.account_status = 'active'
    `, [userId]);

    if (!result.rows[0]) return fastify.sendError(reply, 'Profile not found', 404);
    return fastify.sendSuccess(reply, result.rows[0]);
  });

  // POST /profile — create profile
  fastify.post('/', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['display_name', 'gender', 'age', 'city', 'intent'],
        properties: {
          display_name: { type: 'string', minLength: 2, maxLength: 30 },
          gender: { type: 'string', enum: ['man', 'woman', 'nonbinary', 'prefer_not_say'] },
          age: { type: 'integer', minimum: 18, maximum: 100 },
          city: { type: 'string' },
          intent: { type: 'string' },
          personality_tags: { type: 'array', items: { type: 'string' }, maxItems: 10 },
          bio_prompt_responses: { type: 'array' },
          language_prefs: { type: 'array', items: { type: 'string' } },
        },
      },
    },
  }, async (req, reply) => {
    const { display_name, gender, age, city, intent, personality_tags = [], bio_prompt_responses = [], language_prefs = ['hindi_english'] } = req.body;
    const userId = req.user.uid;

    await fastify.db.query(`
      UPDATE users SET gender = $1, age = $2, city = $3, is_onboarded = true WHERE id = $4
    `, [gender, age, city, userId]);

    const existing = await fastify.db.query('SELECT user_id FROM profiles WHERE user_id = $1', [userId]);

    if (existing.rows[0]) {
      await fastify.db.query(`
        UPDATE profiles SET display_name=$1, intent=$2, personality_tags=$3,
          bio_prompt_responses=$4, language_prefs=$5, updated_at=NOW()
        WHERE user_id=$6
      `, [display_name, intent, personality_tags, JSON.stringify(bio_prompt_responses), language_prefs, userId]);
    } else {
      await fastify.db.query(`
        INSERT INTO profiles (user_id, display_name, intent, personality_tags, bio_prompt_responses, language_prefs, trust_score, photos_blurred, is_searchable)
        VALUES ($1,$2,$3,$4,$5,$6, 50, true, true)
      `, [userId, display_name, intent, personality_tags, JSON.stringify(bio_prompt_responses), language_prefs]);
    }

    // Award trust score for profile completion
    const completeness = [display_name, intent, personality_tags.length > 0].filter(Boolean).length;
    const delta = completeness * 5;
    if (delta > 0) {
      await fastify.db.query(`
        UPDATE profiles SET trust_score = LEAST(100, trust_score + $1), profile_completeness = $2 WHERE user_id = $3
      `, [delta, Math.round(completeness / 3 * 100), userId]);
    }

    return fastify.sendSuccess(reply, { updated: true });
  });

  // POST /profile/voice — upload voice intro URL
  fastify.post('/voice', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['voice_url'],
        properties: {
          voice_url: { type: 'string', format: 'uri' },
          transcript: { type: 'string', maxLength: 500 },
        },
      },
    },
  }, async (req, reply) => {
    const { voice_url, transcript } = req.body;
    await fastify.db.query(`
      UPDATE profiles SET voice_intro_url=$1, voice_transcript=$2, updated_at=NOW(),
        trust_score = LEAST(100, trust_score + 10), profile_completeness = LEAST(100, profile_completeness + 20)
      WHERE user_id=$3
    `, [voice_url, transcript || null, req.user.uid]);

    await fastify.redis.lPush('ai_voice_queue', JSON.stringify({
      user_id: req.user.uid, voice_url, transcript,
    }));

    return fastify.sendSuccess(reply, { uploaded: true });
  });

  // POST /profile/photo — add photo URL
  fastify.post('/photo', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['photo_url'],
        properties: {
          photo_url: { type: 'string', format: 'uri' },
          position: { type: 'integer', minimum: 0, maximum: 5 },
        },
      },
    },
  }, async (req, reply) => {
    const { photo_url, position = 0 } = req.body;
    await fastify.db.query(`
      UPDATE profiles
      SET photo_urls = array_append(photo_urls, $1),
          trust_score = LEAST(100, trust_score + 5),
          profile_completeness = LEAST(100, profile_completeness + 10),
          updated_at = NOW()
      WHERE user_id = $2
    `, [photo_url, req.user.uid]);

    return fastify.sendSuccess(reply, { added: true });
  });

  // DELETE /profile/photo — remove photo
  fastify.delete('/photo', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['photo_url'],
        properties: { photo_url: { type: 'string' } },
      },
    },
  }, async (req, reply) => {
    await fastify.db.query(`
      UPDATE profiles SET photo_urls = array_remove(photo_urls, $1) WHERE user_id = $2
    `, [req.body.photo_url, req.user.uid]);
    return fastify.sendSuccess(reply, { removed: true });
  });

  // PATCH /profile/settings — update privacy settings
  fastify.patch('/settings', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        properties: {
          is_searchable: { type: 'boolean' },
          ghost_mode: { type: 'boolean' },
          women_only_mode: { type: 'boolean' },
          photos_blurred: { type: 'boolean' },
        },
      },
    },
  }, async (req, reply) => {
    const { is_searchable, ghost_mode, women_only_mode, photos_blurred } = req.body;
    const updates = [];
    const params = [req.user.uid];
    let i = 2;
    if (is_searchable !== undefined) { updates.push(`is_searchable=$${i++}`); params.push(is_searchable); }
    if (ghost_mode !== undefined) { updates.push(`ghost_mode=$${i++}`); params.push(ghost_mode); }
    if (women_only_mode !== undefined) { updates.push(`women_only_mode=$${i++}`); params.push(women_only_mode); }
    if (photos_blurred !== undefined) { updates.push(`photos_blurred=$${i++}`); params.push(photos_blurred); }
    if (updates.length === 0) return fastify.sendError(reply, 'No fields to update', 400);

    await fastify.db.query(`UPDATE profiles SET ${updates.join(',')} WHERE user_id=$1`, params);
    return fastify.sendSuccess(reply, { updated: true });
  });
};
