'use strict';
const { v4: uuidv4 } = require('uuid');

module.exports = async function communityRoutes(fastify) {
  // GET /rooms — list available rooms
  fastify.get('/', {
    onRequest: [fastify.authenticate],
    schema: {
      querystring: {
        type: 'object',
        properties: {
          type: { type: 'string' },
          city: { type: 'string' },
          limit: { type: 'integer', minimum: 1, maximum: 50, default: 20 },
          offset: { type: 'integer', minimum: 0, default: 0 },
        },
      },
    },
  }, async (req, reply) => {
    const { type, city, limit = 20, offset = 0 } = req.query;
    const userId = req.user.uid;

    // Get user's gender for women_only filter
    const userResult = await fastify.db.query('SELECT gender FROM users WHERE id = $1', [userId]);
    const isWoman = userResult.rows[0]?.gender === 'woman';

    const filters = ['r.is_active = true'];
    const params = [userId, limit, offset];
    let i = 4;

    if (type) { filters.push(`r.room_type = $${i++}`); params.push(type); }
    if (city) { filters.push(`r.city = $${i++}`); params.push(city); }
    if (!isWoman) filters.push("r.room_type != 'women_only'");

    const result = await fastify.db.query(`
      SELECT r.id, r.name, r.description, r.room_type, r.city, r.tags,
             r.member_count, r.post_count, r.cover_image_url, r.created_at,
             CASE WHEN rm.user_id IS NOT NULL THEN true ELSE false END as is_member
      FROM rooms r
      LEFT JOIN room_members rm ON rm.room_id = r.id AND rm.user_id = $1
      WHERE ${filters.join(' AND ')}
      ORDER BY r.member_count DESC, r.post_count DESC
      LIMIT $2 OFFSET $3
    `, params);

    return fastify.sendSuccess(reply, result.rows, { total: result.rows.length, offset, limit });
  });

  // GET /rooms/:roomId — room detail + recent posts
  fastify.get('/:roomId', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { roomId } = req.params;
    const userId = req.user.uid;

    const roomResult = await fastify.db.query(`
      SELECT r.*, CASE WHEN rm.user_id IS NOT NULL THEN true ELSE false END as is_member
      FROM rooms r
      LEFT JOIN room_members rm ON rm.room_id = r.id AND rm.user_id = $2
      WHERE r.id = $1 AND r.is_active = true
    `, [roomId, userId]);

    if (!roomResult.rows[0]) return fastify.sendError(reply, 'Room not found', 404);

    const postsResult = await fastify.db.query(`
      SELECT rp.id, rp.content, rp.post_type, rp.media_url, rp.like_count,
             rp.comment_count, rp.created_at, rp.moderation_status,
             p.display_name as author_name, p.photos_blurred, p.trust_score
      FROM room_posts rp
      JOIN profiles p ON p.user_id = rp.author_id
      WHERE rp.room_id = $1 AND rp.moderation_status != 'removed'
      ORDER BY rp.created_at DESC LIMIT 20
    `, [roomId]);

    return fastify.sendSuccess(reply, {
      room: roomResult.rows[0],
      posts: postsResult.rows,
    });
  });

  // POST /rooms/join — join a room
  fastify.post('/join', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['room_id'],
        properties: { room_id: { type: 'string' } },
      },
    },
  }, async (req, reply) => {
    const { room_id } = req.body;
    const userId = req.user.uid;

    // Women-only check
    const roomResult = await fastify.db.query('SELECT room_type FROM rooms WHERE id = $1', [room_id]);
    if (!roomResult.rows[0]) return fastify.sendError(reply, 'Room not found', 404);

    if (roomResult.rows[0].room_type === 'women_only') {
      const userGender = await fastify.db.query('SELECT gender FROM users WHERE id = $1', [userId]);
      if (userGender.rows[0]?.gender !== 'woman') {
        return fastify.sendError(reply, 'This room is for women only', 403);
      }
    }

    await fastify.db.query(`
      INSERT INTO room_members (user_id, room_id, joined_at)
      VALUES ($1, $2, NOW()) ON CONFLICT DO NOTHING
    `, [userId, room_id]);

    await fastify.db.query(`
      UPDATE rooms SET member_count = member_count + 1 WHERE id = $1
    `, [room_id]);

    return fastify.sendSuccess(reply, { joined: true });
  });

  // DELETE /rooms/:roomId/leave
  fastify.delete('/:roomId/leave', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { roomId } = req.params;
    await fastify.db.query(`
      DELETE FROM room_members WHERE user_id = $1 AND room_id = $2
    `, [req.user.uid, roomId]);
    await fastify.db.query(`
      UPDATE rooms SET member_count = GREATEST(0, member_count - 1) WHERE id = $1
    `, [roomId]);
    return fastify.sendSuccess(reply, { left: true });
  });

  // POST /rooms/posts — create a post in a room
  fastify.post('/posts', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['room_id', 'content', 'post_type'],
        properties: {
          room_id: { type: 'string' },
          content: { type: 'string', maxLength: 2000 },
          post_type: { type: 'string', enum: ['text', 'voice', 'poll', 'question'] },
          media_url: { type: 'string' },
          poll_options: { type: 'array', items: { type: 'string' } },
        },
      },
    },
  }, async (req, reply) => {
    const { room_id, content, post_type, media_url, poll_options } = req.body;
    const userId = req.user.uid;

    // Check membership
    const isMember = await fastify.db.query(`
      SELECT 1 FROM room_members WHERE user_id = $1 AND room_id = $2
    `, [userId, room_id]);
    if (!isMember.rows[0]) return fastify.sendError(reply, 'Join the room first', 403);

    const postId = uuidv4();
    await fastify.db.query(`
      INSERT INTO room_posts (id, room_id, author_id, content, post_type, media_url, poll_options, moderation_status, created_at)
      VALUES ($1,$2,$3,$4,$5,$6,$7,'approved',NOW())
    `, [postId, room_id, userId, content, post_type, media_url || null, JSON.stringify(poll_options || [])]);

    await fastify.db.query(`
      UPDATE rooms SET post_count = post_count + 1, last_activity_at = NOW() WHERE id = $1
    `, [room_id]);

    // Queue for AI moderation
    await fastify.redis.lPush('moderation_queue', JSON.stringify({
      type: 'room_post', post_id: postId, user_id: userId, text: content,
    }));

    return fastify.sendSuccess(reply, { post_id: postId });
  });

  // POST /rooms/posts/:postId/like
  fastify.post('/posts/:postId/like', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { postId } = req.params;
    await fastify.db.query(`
      UPDATE room_posts SET like_count = like_count + 1 WHERE id = $1
    `, [postId]);
    return fastify.sendSuccess(reply, { liked: true });
  });
};
