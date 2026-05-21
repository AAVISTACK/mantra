'use strict';

module.exports = async function adminRoutes(fastify) {
  // All admin routes require auth + admin role check
  fastify.addHook('onRequest', fastify.authenticate);
  fastify.addHook('preHandler', async (req, reply) => {
    const result = await fastify.db.query(`
      SELECT is_admin FROM users WHERE id = $1
    `, [req.user.uid]);
    if (!result.rows[0]?.is_admin) {
      return reply.code(403).send({ success: false, error: 'Forbidden' });
    }
  });

  // GET /admin/dashboard — stats overview
  fastify.get('/dashboard', async (req, reply) => {
    const [users, reports, revenue, activeToday] = await Promise.all([
      fastify.db.query(`SELECT COUNT(*) as total, COUNT(*) FILTER (WHERE created_at > NOW()-INTERVAL '24h') as new_today FROM users`),
      fastify.db.query(`SELECT COUNT(*) as total, COUNT(*) FILTER (WHERE status='pending') as pending FROM reports`),
      fastify.db.query(`SELECT COALESCE(SUM(amount),0) as total_paise, COUNT(*) as count FROM payment_orders WHERE status='paid' AND paid_at > NOW()-INTERVAL '30d'`),
      fastify.db.query(`SELECT COUNT(DISTINCT id) as count FROM users WHERE last_active > NOW()-INTERVAL '24h'`),
    ]);

    return fastify.sendSuccess(reply, {
      users: { total: +users.rows[0].total, new_today: +users.rows[0].new_today },
      reports: { total: +reports.rows[0].total, pending: +reports.rows[0].pending },
      revenue_30d: { total_inr: +revenue.rows[0].total_paise / 100, count: +revenue.rows[0].count },
      active_today: +activeToday.rows[0].count,
    });
  });

  // GET /admin/reports — pending reports queue
  fastify.get('/reports', {
    schema: {
      querystring: {
        type: 'object',
        properties: {
          status: { type: 'string', enum: ['pending', 'reviewing', 'resolved', 'dismissed'], default: 'pending' },
          limit: { type: 'integer', default: 20 },
          offset: { type: 'integer', default: 0 },
        },
      },
    },
  }, async (req, reply) => {
    const { status = 'pending', limit = 20, offset = 0 } = req.query;
    const result = await fastify.db.query(`
      SELECT r.id, r.reason, r.note, r.status, r.created_at,
             reporter.display_name as reporter_name,
             reported.display_name as reported_name,
             u_reported.trust_score as trust_score
      FROM reports r
      JOIN profiles reporter ON reporter.user_id = r.reporter_id
      JOIN profiles reported ON reported.user_id = r.reported_user_id
      JOIN profiles u_reported ON u_reported.user_id = r.reported_user_id
      WHERE r.status = $1
      ORDER BY r.created_at ASC
      LIMIT $2 OFFSET $3
    `, [status, limit, offset]);
    return fastify.sendSuccess(reply, result.rows);
  });

  // PATCH /admin/reports/:reportId — resolve/dismiss report
  fastify.patch('/reports/:reportId', {
    schema: {
      body: {
        type: 'object',
        required: ['action'],
        properties: {
          action: { type: 'string', enum: ['resolve', 'dismiss', 'ban', 'shadow_ban', 'warn'] },
          note: { type: 'string' },
        },
      },
    },
  }, async (req, reply) => {
    const { reportId } = req.params;
    const { action, note } = req.body;

    const reportResult = await fastify.db.query(`
      SELECT reported_user_id FROM reports WHERE id=$1
    `, [reportId]);
    if (!reportResult.rows[0]) return fastify.sendError(reply, 'Report not found', 404);

    const reportedUserId = reportResult.rows[0].reported_user_id;
    const newStatus = ['resolve', 'ban', 'shadow_ban', 'warn'].includes(action) ? 'resolved' : 'dismissed';

    await fastify.db.query(`
      UPDATE reports SET status=$1, resolved_at=NOW(), resolver_note=$2 WHERE id=$3
    `, [newStatus, note || null, reportId]);

    if (action === 'ban') {
      await fastify.db.query(`UPDATE users SET account_status='banned' WHERE id=$1`, [reportedUserId]);
    } else if (action === 'shadow_ban') {
      await fastify.db.query(`UPDATE users SET account_status='shadow_banned' WHERE id=$1`, [reportedUserId]);
      await fastify.db.query(`UPDATE profiles SET is_searchable=false WHERE user_id=$1`, [reportedUserId]);
    } else if (action === 'warn') {
      await fastify.db.query(`UPDATE profiles SET trust_score=GREATEST(0,trust_score-20) WHERE user_id=$1`, [reportedUserId]);
    }

    return fastify.sendSuccess(reply, { action_taken: action });
  });

  // GET /admin/users — search users
  fastify.get('/users', {
    schema: {
      querystring: {
        type: 'object',
        properties: {
          search: { type: 'string' },
          status: { type: 'string' },
          limit: { type: 'integer', default: 20 },
          offset: { type: 'integer', default: 0 },
        },
      },
    },
  }, async (req, reply) => {
    const { search, status, limit = 20, offset = 0 } = req.query;
    const filters = ['1=1'];
    const params = [limit, offset];
    let i = 3;
    if (status) { filters.push(`u.account_status=$${i++}`); params.push(status); }
    if (search) { filters.push(`(p.display_name ILIKE $${i} OR u.city ILIKE $${i++})`); params.push(`%${search}%`); }

    const result = await fastify.db.query(`
      SELECT u.id, u.gender, u.age, u.city, u.account_status, u.is_premium, u.premium_tier,
             u.created_at, u.last_active, p.display_name, p.trust_score, p.verification_level
      FROM users u
      LEFT JOIN profiles p ON p.user_id = u.id
      WHERE ${filters.join(' AND ')}
      ORDER BY u.created_at DESC
      LIMIT $1 OFFSET $2
    `, params);
    return fastify.sendSuccess(reply, result.rows);
  });
};
