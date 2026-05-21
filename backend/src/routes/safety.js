'use strict';

module.exports = async function safetyRoutes(fastify) {
  // POST /safety/report
  fastify.post('/report', {
    onRequest: [fastify.authenticate],
    config: { rateLimit: { max: 10, timeWindow: '1 day' } },
    schema: {
      body: {
        type: 'object',
        required: ['reported_user_id', 'reason'],
        properties: {
          reported_user_id: { type: 'string' },
          reason: { type: 'string', enum: ['inappropriate', 'fake', 'harassment', 'explicit', 'scam', 'other'] },
          note: { type: 'string', maxLength: 500 },
        },
      },
    },
  }, async (req, reply) => {
    const { reported_user_id, reason, note } = req.body;
    const reporter_id = req.user.uid;

    await fastify.db.query(`
      INSERT INTO reports (id, reporter_id, reported_user_id, reason, note, status, created_at)
      VALUES ($1, $2, $3, $4, $5, 'pending', NOW())
    `, [require('crypto').randomUUID(), reporter_id, reported_user_id, reason, note]);

    // Auto-increment creep score on valid reports
    await fastify.db.query(`
      UPDATE profiles SET trust_score = GREATEST(0, trust_score - 5)
      WHERE user_id = $1
    `, [reported_user_id]);

    // Queue for human review
    await fastify.redis.lPush('moderation_queue', JSON.stringify({
      type: 'report',
      reporter_id,
      reported_user_id,
      reason,
      note,
      timestamp: new Date().toISOString(),
    }));

    return fastify.sendSuccess(reply, {
      message: 'Report received. Our team will review within 4 hours.',
    });
  });

  // POST /safety/block
  fastify.post('/block', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['blocked_user_id'],
        properties: { blocked_user_id: { type: 'string' } },
      },
    },
  }, async (req, reply) => {
    const { blocked_user_id } = req.body;
    const blocker_id = req.user.uid;

    await fastify.db.query(`
      INSERT INTO blocks (blocker_id, blocked_id, created_at)
      VALUES ($1, $2, NOW())
      ON CONFLICT DO NOTHING
    `, [blocker_id, blocked_user_id]);

    // Remove any active connections
    const [a, b] = [blocker_id, blocked_user_id].sort();
    await fastify.db.query(`
      UPDATE connections SET status = 'blocked'
      WHERE user_a = $1 AND user_b = $2
    `, [a, b]);

    // Clear spark cache
    await fastify.redis.del(`sparks:${blocker_id}:${new Date().toDateString()}`);

    return fastify.sendSuccess(reply, { blocked: true });
  });

  // POST /safety/sos
  fastify.post('/sos', {
    onRequest: [fastify.authenticate],
  }, async (req, reply) => {
    const { latitude, longitude, conversation_id } = req.body || {};
    const userId = req.user.uid;

    // Get trusted contacts
    const contactsResult = await fastify.db.query(`
      SELECT phone FROM trusted_contacts WHERE user_id = $1
    `, [userId]);

    const contacts = contactsResult.rows;

    // Get user name
    const userResult = await fastify.db.query(`
      SELECT display_name FROM profiles WHERE user_id = $1
    `, [userId]);

    const name = userResult.rows[0]?.display_name || 'Your contact';
    const mapsLink = latitude && longitude
      ? `https://maps.google.com/?q=${latitude},${longitude}`
      : 'Location unavailable';

    // Queue SMS to contacts
    for (const contact of contacts) {
      await fastify.redis.lPush('sms_queue', JSON.stringify({
        to: contact.phone,
        message: `⚠️ MANTRA SAFETY ALERT: ${name} has activated emergency mode. Last known location: ${mapsLink}. Please check on them immediately.`,
      }));
    }

    // Archive conversation if provided
    if (conversation_id) {
      await fastify.db.query(`
        UPDATE connections SET status = 'flagged' WHERE id = $1
      `, [conversation_id]);
    }

    // Log SOS event
    await fastify.db.query(`
      INSERT INTO sos_events (id, user_id, latitude, longitude, contacts_alerted, created_at)
      VALUES ($1, $2, $3, $4, $5, NOW())
    `, [require('crypto').randomUUID(), userId, latitude, longitude, contacts.length]);

    return fastify.sendSuccess(reply, {
      contacts_alerted: contacts.length,
      message: `${contacts.length} contact(s) have been notified.`,
    });
  });

  // POST /safety/trusted-contacts
  fastify.post('/trusted-contacts', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['name', 'phone'],
        properties: {
          name: { type: 'string' },
          phone: { type: 'string' },
        },
      },
    },
  }, async (req, reply) => {
    const { name, phone } = req.body;
    const userId = req.user.uid;

    // Max 3 trusted contacts
    const countResult = await fastify.db.query(`
      SELECT COUNT(*) FROM trusted_contacts WHERE user_id = $1
    `, [userId]);

    if (parseInt(countResult.rows[0].count) >= 3) {
      return fastify.sendError(reply, 'Maximum 3 trusted contacts allowed', 400);
    }

    await fastify.db.query(`
      INSERT INTO trusted_contacts (id, user_id, name, phone, created_at)
      VALUES ($1, $2, $3, $4, NOW())
    `, [require('crypto').randomUUID(), userId, name, phone]);

    // Send intro SMS to contact
    await fastify.redis.lPush('sms_queue', JSON.stringify({
      to: phone,
      message: `Hi ${name}, you've been added as a safety contact for ${userId} on Mantra dating app. If they need help, you'll receive an alert.`,
    }));

    return fastify.sendSuccess(reply, { added: true });
  });
};
