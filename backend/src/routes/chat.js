'use strict';
const { v4: uuidv4 } = require('uuid');

module.exports = async function chatRoutes(fastify) {
  // GET /chat/conversations — list all active conversations
  fastify.get('/conversations', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const userId = req.user.uid;
    const result = await fastify.db.query(`
      SELECT 
        c.id, c.stage, c.status, c.last_message_at, c.message_count,
        c.name_revealed_at, c.photo_revealed_at, c.is_disappearing,
        CASE WHEN c.user_a = $1 THEN c.user_b ELSE c.user_a END as other_user_id,
        p.display_name, p.photos_blurred, p.photo_urls,
        p.voice_intro_url, p.personality_tags,
        m.content as last_message, m.message_type as last_message_type,
        m.created_at as last_message_created_at
      FROM connections c
      JOIN profiles p ON p.user_id = CASE WHEN c.user_a = $1 THEN c.user_b ELSE c.user_a END
      LEFT JOIN LATERAL (
        SELECT content, message_type, created_at FROM messages
        WHERE connection_id = c.id ORDER BY created_at DESC LIMIT 1
      ) m ON true
      WHERE (c.user_a = $1 OR c.user_b = $1) AND c.status = 'connected'
      ORDER BY COALESCE(c.last_message_at, c.connected_at) DESC
    `, [userId]);

    return fastify.sendSuccess(reply, result.rows);
  });

  // GET /chat/:connectionId/messages — paginated messages
  fastify.get('/:connectionId/messages', {
    onRequest: [fastify.authenticate],
    schema: {
      querystring: {
        type: 'object',
        properties: {
          before: { type: 'string' },
          limit: { type: 'integer', minimum: 1, maximum: 50, default: 30 },
        },
      },
    },
  }, async (req, reply) => {
    const { connectionId } = req.params;
    const { before, limit = 30 } = req.query;
    const userId = req.user.uid;

    // Verify user is part of connection
    const connResult = await fastify.db.query(`
      SELECT id, user_a, user_b, stage, status, is_disappearing, disappear_hours
      FROM connections WHERE id = $1 AND (user_a = $2 OR user_b = $2)
    `, [connectionId, userId]);

    if (!connResult.rows[0]) return fastify.sendError(reply, 'Conversation not found', 404);

    const messages = await fastify.db.query(`
      SELECT m.id, m.sender_id, m.content, m.message_type, m.moderation_status,
             m.created_at, m.is_read, m.reaction, m.reply_to_id,
             p.display_name as sender_name
      FROM messages m
      JOIN profiles p ON p.user_id = m.sender_id
      WHERE m.connection_id = $1
        ${before ? 'AND m.created_at < $3' : ''}
        AND m.moderation_status != 'removed'
      ORDER BY m.created_at DESC
      LIMIT $2
    `, before ? [connectionId, limit, before] : [connectionId, limit]);

    // Mark as read
    await fastify.db.query(`
      UPDATE messages SET is_read = true
      WHERE connection_id = $1 AND sender_id != $2 AND is_read = false
    `, [connectionId, userId]);

    return fastify.sendSuccess(reply, messages.rows.reverse(), { hasMore: messages.rows.length === limit });
  });

  // POST /chat/:connectionId/messages — send message
  fastify.post('/:connectionId/messages', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['content', 'message_type'],
        properties: {
          content: { type: 'string', maxLength: 1000 },
          message_type: { type: 'string', enum: ['text', 'voice', 'gif', 'system'] },
          reply_to_id: { type: 'string' },
        },
      },
    },
  }, async (req, reply) => {
    const { connectionId } = req.params;
    const { content, message_type, reply_to_id } = req.body;
    const userId = req.user.uid;

    // Verify access
    const connResult = await fastify.db.query(`
      SELECT id, user_a, user_b, stage, status
      FROM connections WHERE id = $1 AND (user_a = $2 OR user_b = $2) AND status = 'connected'
    `, [connectionId, userId]);

    if (!connResult.rows[0]) return fastify.sendError(reply, 'Conversation not found or inactive', 404);
    const conn = connResult.rows[0];
    const otherId = conn.user_a === userId ? conn.user_b : conn.user_a;

    // AI moderation check
    let moderationStatus = 'approved';
    try {
      const aiRes = await fastify.redis.get(`ai_mod:${userId}:skip`);
      if (!aiRes) {
        // Queue moderation (async — don't block message send)
        await fastify.redis.lPush('moderation_queue', JSON.stringify({
          type: 'message', user_id: userId, connection_id: connectionId, text: content,
        }));
      }
    } catch (_) {}

    const msgId = uuidv4();
    await fastify.db.query(`
      INSERT INTO messages (id, connection_id, sender_id, content, message_type, moderation_status, reply_to_id, created_at)
      VALUES ($1,$2,$3,$4,$5,$6,$7,NOW())
    `, [msgId, connectionId, userId, content, message_type, moderationStatus, reply_to_id || null]);

    // Update connection
    await fastify.db.query(`
      UPDATE connections SET last_message_at = NOW(), message_count = message_count + 1,
        stage = CASE WHEN message_count >= 20 AND stage < 5 THEN LEAST(stage + 1, 5) ELSE stage END
      WHERE id = $1
    `, [connectionId]);

    // Notify other user
    await fastify.redis.publish('notifications', JSON.stringify({
      type: 'new_message',
      target_user_id: otherId,
      data: { connection_id: connectionId, message_id: msgId, message_type, preview: content.slice(0, 50) },
    }));

    return fastify.sendSuccess(reply, { message_id: msgId, created_at: new Date().toISOString() });
  });

  // POST /chat/:connectionId/reaction — react to message
  fastify.post('/:connectionId/reaction', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['message_id', 'reaction'],
        properties: {
          message_id: { type: 'string' },
          reaction: { type: 'string', maxLength: 10 },
        },
      },
    },
  }, async (req, reply) => {
    const { message_id, reaction } = req.body;
    await fastify.db.query(`
      UPDATE messages SET reaction = $1 WHERE id = $2 AND connection_id = $3
    `, [reaction, message_id, req.params.connectionId]);
    return fastify.sendSuccess(reply, { reacted: true });
  });

  // DELETE /chat/:connectionId — unmatch / delete conversation
  fastify.delete('/:connectionId', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const { connectionId } = req.params;
    await fastify.db.query(`
      UPDATE connections SET status = 'disconnected' WHERE id = $1 AND (user_a = $2 OR user_b = $2)
    `, [connectionId, req.user.uid]);
    return fastify.sendSuccess(reply, { deleted: true });
  });
};
