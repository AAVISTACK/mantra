// backend/src/index.js
// Mantra Backend — Node.js + Fastify + PostgreSQL + Redis + Firebase

'use strict';


// ─── Environment Validation ───────────────────────────────
(function validateEnv() {
  const required = {
    JWT_SECRET:         { minLength: 32 },
    PHONE_HASH_SECRET:  { minLength: 16 },
    DATABASE_URL:       {},
    REDIS_URL:          {},
  };
  const errors = [];
  for (const [key, opts] of Object.entries(required)) {
    const val = process.env[key];
    if (!val) errors.push(`Missing required env: ${key}`);
    else if (opts.minLength && val.length < opts.minLength)
      errors.push(`${key} must be >= ${opts.minLength} chars (got ${val.length})`);
  }
  if (errors.length) {
    console.error('\n[STARTUP ERROR] Environment validation failed:');
    errors.forEach(e => console.error(`  ✗ ${e}`));
    process.exit(1);
  }
})();

const Fastify = require('fastify');
const cors = require('@fastify/cors');
const helmet = require('@fastify/helmet');
const rateLimit = require('@fastify/rate-limit');
const jwt = require('@fastify/jwt');
const multipart = require('@fastify/multipart');
const { createClient } = require('redis');
const { Pool } = require('pg');

const authRoutes = require('./routes/auth');
const profileRoutes = require('./routes/profile');
const matchRoutes = require('./routes/match');
const chatRoutes = require('./routes/chat');
const communityRoutes = require('./routes/community');
const safetyRoutes = require('./routes/safety');
const paymentRoutes = require('./routes/payment');
const adminRoutes = require('./routes/admin');

const app = Fastify({
  logger: {
    level: process.env.LOG_LEVEL || 'info',
    transport: process.env.NODE_ENV === 'development'
      ? { target: 'pino-pretty' }
      : undefined,
  },
  trustProxy: true,
});

// ─── Database Pool ────────────────────────────────────────
const db = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: true } : false,
});

// ─── Redis Client ─────────────────────────────────────────
const redis = createClient({
  url: process.env.REDIS_URL,
  socket: { reconnectStrategy: (retries) => Math.min(retries * 100, 3000) },
});

// ─── Plugins ──────────────────────────────────────────────
async function registerPlugins() {
  await app.register(helmet, {
    contentSecurityPolicy: false,
  });

  await app.register(cors, {
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
    credentials: true,
  });

  await app.register(rateLimit, {
    global: true,
    max: 100,
    timeWindow: '1 minute',
    redis,
    keyGenerator: (req) => req.ip,
    errorResponseBuilder: () => ({
      statusCode: 429,
      error: 'Too Many Requests',
      message: 'Slow down. Try again in a moment.',
    }),
  });

  await app.register(jwt, {
    secret: process.env.JWT_SECRET,
    sign: { expiresIn: '15m' },
  });

  await app.register(multipart, {
    limits: {
      fileSize: 50 * 1024 * 1024, // 50MB
      files: 6,
    },
  });
}

// ─── Decorators ───────────────────────────────────────────
function registerDecorators() {
  app.decorate('db', db);
  app.decorate('redis', redis);

  // Auth middleware
  app.decorate('authenticate', async function (req, reply) {
    try {
      await req.jwtVerify();
      // Check token not in blacklist
      const blacklisted = await redis.get(`blacklist:${req.user.jti}`);
      if (blacklisted) {
        return reply.code(401).send({ error: 'Token revoked' });
      }
    } catch (err) {
      reply.code(401).send({ error: 'Unauthorized' });
    }
  });

  // Response helper
  app.decorate('sendSuccess', function (reply, data, meta = {}) {
    return reply.send({ success: true, data, meta });
  });

  app.decorate('sendError', function (reply, message, statusCode = 400) {
    return reply.code(statusCode).send({ success: false, error: message });
  });
}

// ─── Routes ───────────────────────────────────────────────
function registerRoutes() {
  const prefix = '/api/v1';

  app.register(authRoutes, { prefix: `${prefix}/auth` });
  app.register(profileRoutes, { prefix: `${prefix}/profile` });
  app.register(matchRoutes, { prefix: `${prefix}/match` });
  app.register(chatRoutes, { prefix: `${prefix}/chat` });
  app.register(communityRoutes, { prefix: `${prefix}/rooms` });
  app.register(safetyRoutes, { prefix: `${prefix}/safety` });
  app.register(paymentRoutes, { prefix: `${prefix}/payment` });
  app.register(adminRoutes, { prefix: `${prefix}/admin` });

  // Health check
  app.get('/health', async () => ({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version,
  }));
}

// ─── Error Handler ────────────────────────────────────────
function registerErrorHandlers() {
  app.setErrorHandler((error, req, reply) => {
    req.log.error(error);

    if (error.validation) {
      return reply.code(422).send({
        success: false,
        error: 'Validation failed',
        details: error.validation,
      });
    }

    if (error.statusCode === 429) {
      return reply.code(429).send({
        success: false,
        error: 'Rate limit exceeded',
      });
    }

    return reply.code(error.statusCode || 500).send({
      success: false,
      error: process.env.NODE_ENV === 'production'
        ? 'Internal server error'
        : error.message,
    });
  });

  app.setNotFoundHandler((req, reply) => {
    reply.code(404).send({ success: false, error: 'Route not found' });
  });
}

// ─── Startup ──────────────────────────────────────────────
async function start() {
  try {
    await redis.connect();
    app.log.info('Redis connected');

    await db.query('SELECT 1');
    app.log.info('PostgreSQL connected');

    await registerPlugins();
    registerDecorators();
    registerRoutes();
    registerErrorHandlers();

    const port = parseInt(process.env.PORT || '8000');
    const host = process.env.HOST || '0.0.0.0';

    await app.listen({ port, host });
    app.log.info(`Mantra API running on ${host}:${port}`);

  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  await app.close();
  await redis.quit();
  await db.end();
  process.exit(0);
});

start();
