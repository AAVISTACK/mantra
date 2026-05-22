'use strict';

const admin = require('firebase-admin');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

function hashPhone(raw) {
  return crypto
    .createHmac('sha256', process.env.PHONE_HASH_SECRET)
    .update(raw)
    .digest('hex');
}

module.exports = async function authRoutes(fastify) {

  // POST /auth/register
  fastify.post('/register', {
    schema: {
      headers: {
        type: 'object',
        required: ['authorization'],
        properties: { authorization: { type: 'string' } },
      },
    },
  }, async (req, reply) => {
    const firebaseToken = req.headers.authorization?.replace('Bearer ', '');
    if (!firebaseToken) return fastify.sendError(reply, 'No Firebase token', 401);

    let decoded;
    try {
      decoded = await admin.auth().verifyIdToken(firebaseToken);
    } catch {
      return fastify.sendError(reply, 'Invalid Firebase token', 401);
    }

    const raw = decoded.phone_number || decoded.uid;
    if (!raw) return fastify.sendError(reply, 'Token missing phone identifier', 400);

    const phoneHash = hashPhone(raw);

    const result = await fastify.db.query(`
      INSERT INTO users (id, phone_hash, firebase_uid, verification_level, account_status, created_at, last_active, is_onboarded)
      VALUES ($1, $2, $3, 1, 'active', NOW(), NOW(), false)
      ON CONFLICT (phone_hash) DO UPDATE SET last_active = NOW(), firebase_uid = EXCLUDED.firebase_uid
      RETURNING id, is_onboarded, verification_level
    `, [uuidv4(), phoneHash, decoded.uid]);

    const user = result.rows[0];
    const accessToken = fastify.jwt.sign({ uid: user.id, jti: uuidv4() }, { expiresIn: '15m' });
    const refreshToken = fastify.jwt.sign({ uid: user.id, type: 'refresh', jti: uuidv4() }, { expiresIn: '7d' });
    await fastify.redis.setEx(`refresh:${user.id}`, 7 * 24 * 3600, refreshToken);

    return fastify.sendSuccess(reply, {
      access_token: accessToken,
      refresh_token: refreshToken,
      user: { id: user.id, is_onboarded: user.is_onboarded },
    });
  });

  // POST /auth/refresh — rotate BOTH tokens
  fastify.post('/refresh', {
    schema: {
      body: {
        type: 'object',
        required: ['refresh_token'],
        properties: { refresh_token: { type: 'string' } },
      },
    },
  }, async (req, reply) => {
    const { refresh_token } = req.body;
    let decoded;
    try { decoded = fastify.jwt.verify(refresh_token); }
    catch { return fastify.sendError(reply, 'Invalid refresh token', 401); }

    if (decoded.type !== 'refresh') return fastify.sendError(reply, 'Invalid token type', 401);

    const stored = await fastify.redis.get(`refresh:${decoded.uid}`);
    if (stored !== refresh_token) {
      await fastify.redis.del(`refresh:${decoded.uid}`);
      return fastify.sendError(reply, 'Token reuse detected — all sessions revoked', 401);
    }

    const newAccess  = fastify.jwt.sign({ uid: decoded.uid, jti: uuidv4() }, { expiresIn: '15m' });
    const newRefresh = fastify.jwt.sign({ uid: decoded.uid, type: 'refresh', jti: uuidv4() }, { expiresIn: '7d' });
    await fastify.redis.del(`refresh:${decoded.uid}`);
    await fastify.redis.setEx(`refresh:${decoded.uid}`, 7 * 24 * 3600, newRefresh);

    return fastify.sendSuccess(reply, { access_token: newAccess, refresh_token: newRefresh });
  });

  // GET /auth/me
  fastify.get('/me', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const result = await fastify.db.query(`
      SELECT u.id, u.verification_level, u.account_status, u.gender, u.age,
             u.city, u.created_at, u.last_active, u.is_premium, u.premium_tier,
             u.is_onboarded, u.kyc_level,
             p.display_name, p.trust_score, p.photo_urls, p.voice_intro_url,
             p.bio_prompt_responses, p.personality_tags, p.intent, p.profile_completeness
      FROM users u
      LEFT JOIN profiles p ON p.user_id = u.id
      WHERE u.id = $1
    `, [req.user.uid]);
    if (!result.rows[0]) return fastify.sendError(reply, 'User not found', 404);
    return fastify.sendSuccess(reply, result.rows[0]);
  });

  // POST /auth/logout
  fastify.post('/logout', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const ttl = Math.max(0, req.user.exp - Math.floor(Date.now() / 1000));
    if (ttl > 0) await fastify.redis.setEx(`blacklist:${req.user.jti}`, ttl, '1');
    await fastify.redis.del(`refresh:${req.user.uid}`);
    return fastify.sendSuccess(reply, { message: 'Logged out' });
  });

  // POST /auth/fcm-token
  fastify.post('/fcm-token', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['fcm_token'],
        properties: { fcm_token: { type: 'string', minLength: 10 } },
      },
    },
  }, async (req, reply) => {
    await fastify.db.query('UPDATE users SET fcm_token = $1 WHERE id = $2', [req.body.fcm_token, req.user.uid]);
    return fastify.sendSuccess(reply, { saved: true });
  });
};
