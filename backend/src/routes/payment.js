'use strict';
const Razorpay = require('razorpay');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

module.exports = async function paymentRoutes(fastify) {
  const razorpay = new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID,
    key_secret: process.env.RAZORPAY_KEY_SECRET,
  });

  const PLANS = {
    gold_monthly:    { amount: 39900,  currency: 'INR', duration_days: 30,  tier: 'gold' },
    gold_quarterly:  { amount: 99900,  currency: 'INR', duration_days: 90,  tier: 'gold' },
    platinum_monthly:{ amount: 79900,  currency: 'INR', duration_days: 30,  tier: 'platinum' },
    platinum_yearly: { amount: 699900, currency: 'INR', duration_days: 365, tier: 'platinum' },
  };

  // POST /payment/order — create Razorpay order
  fastify.post('/order', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['plan_id'],
        properties: {
          plan_id: { type: 'string', enum: Object.keys(PLANS) },
        },
      },
    },
  }, async (req, reply) => {
    const { plan_id } = req.body;
    const plan = PLANS[plan_id];

    const order = await razorpay.orders.create({
      amount: plan.amount,
      currency: plan.currency,
      receipt: `mantra_${req.user.uid}_${Date.now()}`,
      notes: { user_id: req.user.uid, plan_id, tier: plan.tier },
    });

    // Store pending order
    await fastify.db.query(`
      INSERT INTO payment_orders (id, user_id, razorpay_order_id, plan_id, amount, status, created_at)
      VALUES ($1,$2,$3,$4,$5,'pending',NOW())
    `, [uuidv4(), req.user.uid, order.id, plan_id, plan.amount]);

    return fastify.sendSuccess(reply, {
      order_id: order.id,
      amount: plan.amount,
      currency: plan.currency,
      key_id: process.env.RAZORPAY_KEY_ID,
      plan: { id: plan_id, tier: plan.tier, duration_days: plan.duration_days },
    });
  });

  // POST /payment/verify — verify payment & activate premium
  fastify.post('/verify', {
    onRequest: [fastify.authenticate],
    schema: {
      body: {
        type: 'object',
        required: ['razorpay_order_id', 'razorpay_payment_id', 'razorpay_signature'],
        properties: {
          razorpay_order_id: { type: 'string' },
          razorpay_payment_id: { type: 'string' },
          razorpay_signature: { type: 'string' },
        },
      },
    },
  }, async (req, reply) => {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;

    // Verify signature
    const expectedSig = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(`${razorpay_order_id}|${razorpay_payment_id}`)
      .digest('hex');

    if (expectedSig !== razorpay_signature) {
      return fastify.sendError(reply, 'Payment verification failed', 400);
    }

    // Get order details
    const orderResult = await fastify.db.query(`
      SELECT plan_id FROM payment_orders WHERE razorpay_order_id = $1 AND user_id = $2
    `, [razorpay_order_id, req.user.uid]);

    if (!orderResult.rows[0]) return fastify.sendError(reply, 'Order not found', 404);

    const plan = PLANS[orderResult.rows[0].plan_id];
    const expiresAt = new Date(Date.now() + plan.duration_days * 86400 * 1000);

    // Update user premium status
    await fastify.db.query(`
      UPDATE users SET is_premium=true, premium_tier=$1, premium_expires_at=$2 WHERE id=$3
    `, [plan.tier, expiresAt, req.user.uid]);

    // Mark order as paid
    await fastify.db.query(`
      UPDATE payment_orders SET status='paid', razorpay_payment_id=$1, paid_at=NOW()
      WHERE razorpay_order_id=$2
    `, [razorpay_payment_id, razorpay_order_id]);

    // Trust score boost for premium
    await fastify.db.query(`
      UPDATE profiles SET trust_score = LEAST(100, trust_score + 10) WHERE user_id = $1
    `, [req.user.uid]);

    return fastify.sendSuccess(reply, {
      activated: true,
      tier: plan.tier,
      expires_at: expiresAt.toISOString(),
    });
  });

  // POST /payment/webhook — Razorpay webhook
  fastify.post('/webhook', async (req, reply) => {
    const signature = req.headers['x-razorpay-signature'];
    const body = JSON.stringify(req.body);
    const expectedSig = crypto
      .createHmac('sha256', process.env.RAZORPAY_WEBHOOK_SECRET)
      .update(body).digest('hex');

    if (signature !== expectedSig) {
      return reply.code(400).send({ error: 'Invalid signature' });
    }

    const { event, payload } = req.body;
    if (event === 'payment.failed') {
      const orderId = payload?.payment?.entity?.order_id;
      if (orderId) {
        await fastify.db.query(`
          UPDATE payment_orders SET status='failed' WHERE razorpay_order_id=$1
        `, [orderId]);
      }
    }

    return reply.send({ received: true });
  });

  // GET /payment/status — get current premium status
  fastify.get('/status', { onRequest: [fastify.authenticate] }, async (req, reply) => {
    const result = await fastify.db.query(`
      SELECT is_premium, premium_tier, premium_expires_at FROM users WHERE id=$1
    `, [req.user.uid]);
    return fastify.sendSuccess(reply, result.rows[0] || {});
  });
};
