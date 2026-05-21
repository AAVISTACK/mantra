// backend/src/routes/auth.js
'use strict';

const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcryptjs');

module.exports = async function authRoutes(fastify) {
  // POST /auth/register — called after Firebase phone auth
  fastify.post('/register', {
    schema: {
      body: {
        type: 'object',
        required: [],
        properties: {},
      },
    },
  }, async (req, reply) => {
    const firebaseToken = req.headers.authorization?.replace('Bearer ', '');
    if (!firebaseToken) {
      return fastify.sendError(reply, 'No token provided', 401);
    }

    let decoded;
    try {
      decoded = await admin.auth().verifyIdToken(firebaseToken);
    } catch {
      return fastify.sendError(reply, 'Invalid Firebase token', 401);
    }

    const phoneHash = await bcrypt.hash(decoded.phone_number || decoded.uid, 10);

    // Upsert user
    const result = await fastify.db.query(`
      INSERT INTO users (id, phone_hash, verification_level, account_status, created_at, last_active, is_onboarded)
      VALUES ($1, $2, 1, 'active', NOW(), NOW(), false)
      ON CONFLICT (phone_hash) DO UPDATE SET last_active = NOW()
      RETURNING id, is_onboarded, verification_level
    `, [uuidv4(), phoneHash]);

    const user = result.rows[0];

    const accessToken = fastify.jwt.sign(
      { uid: user.id, jti: uuidv4() },
      { expiresIn: '15m' }
    );
    const refreshToken = fastify.jwt.sign(
      { uid: user.id, type: 'refresh', jti: uuidv4() },
      { expiresIn: '7d' }
    );

    // Store refresh token
    await fastify.redis.setEx(`refresh:${user.id}`, 7 * 24 * 3600, refreshToken);

    return fastify.sendSuccess(reply, {
      access_token: accessToken,
      refresh_token: refreshToken,
      user: { id: user.id, is_onboarded: user.is_onboarded },
    });
  });

  // POST /auth/refresh
  fastify.post('/refresh', async (req, reply) => {
    const { refresh_token } = req.body || {};
    if (!refresh_token) return fastify.sendError(reply, 'No refresh token', 400);

    let decoded;
    try {
      decoded = fastify.jwt.verify(refresh_token);
    } catch {
      return fastify.sendError(reply, 'Invalid refresh token', 401);
    }

    if (decoded.type !== 'refresh') {
      return fastify.sendError(reply, 'Invalid token type', 401);
    }

    const stored = await fastify.redis.get(`refresh:${decoded.uid}`);
    if (stored !== refresh_token) {
      return fastify.sendError(reply, 'Token reuse detected', 401);
    }

    const newJti = uuidv4();
    const accessToken = fastify.jwt.sign(
      { uid: decoded.uid, jti: newJti },
      { expiresIn: '15m' }
    );

    return fastify.sendSuccess(reply, { access_token: accessToken });
  });

  // GET /auth/me
  fastify.get('/me', {
    onRequest: [fastify.authenticate],
  }, async (req, reply) => {
    const result = await fastify.db.query(`
      SELECT u.id, u.verification_level, u.account_status, u.gender, u.age,
             u.city, u.created_at, u.last_active, u.is_premium, u.premium_tier,
             u.is_onboarded
      FROM users u
      WHERE u.id = $1
    `, [req.user.uid]);

    if (!result.rows[0]) {
      return fastify.sendError(reply, 'User not found', 404);
    }

    return fastify.sendSuccess(reply, result.rows[0]);
  });

  // POST /auth/logout
  fastify.post('/logout', {
    onRequest: [fastify.authenticate],
  }, async (req, reply) => {
    // Blacklist the token
    const ttl = Math.max(0, req.user.exp - Math.floor(Date.now() / 1000));
    if (ttl > 0) {
      await fastify.redis.setEx(`blacklist:${req.user.jti}`, ttl, '1');
    }
    await fastify.redis.del(`refresh:${req.user.uid}`);

    return fastify.sendSuccess(reply, { message: 'Logged out' });
  });
};
