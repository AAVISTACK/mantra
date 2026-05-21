-- backend/database/schema.sql
-- Mantra Complete PostgreSQL Schema
-- Run: psql $DATABASE_URL -f schema.sql

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ─── ENUMS ────────────────────────────────────────────────────────────

CREATE TYPE account_status AS ENUM ('active', 'suspended', 'banned', 'shadow_banned', 'deleted');
CREATE TYPE gender_type AS ENUM ('man', 'woman', 'nonbinary', 'prefer_not_say');
CREATE TYPE connection_status AS ENUM ('pending', 'connected', 'disconnected', 'blocked', 'flagged');
CREATE TYPE report_reason AS ENUM ('inappropriate', 'fake', 'harassment', 'explicit', 'scam', 'other');
CREATE TYPE report_status AS ENUM ('pending', 'reviewing', 'resolved', 'dismissed');
CREATE TYPE premium_tier AS ENUM ('gold', 'platinum');
CREATE TYPE room_type AS ENUM ('interest', 'city', 'career', 'emotion', 'activity', 'women_only', 'language');
CREATE TYPE message_type AS ENUM ('text', 'voice', 'gif', 'system');
CREATE TYPE moderation_status AS ENUM ('approved', 'flagged', 'removed', 'pending');
CREATE TYPE kyc_level AS ENUM ('unverified', 'phone', 'id_verified', 'face_verified', 'fully_verified');

-- ─── USERS ────────────────────────────────────────────────────────────

CREATE TABLE users (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone_hash          VARCHAR(64) UNIQUE NOT NULL,
  email_hash          VARCHAR(64),
  firebase_uid        VARCHAR(128) UNIQUE,
  verification_level  SMALLINT DEFAULT 1 CHECK (verification_level BETWEEN 1 AND 5),
  kyc_level           kyc_level DEFAULT 'phone',
  account_status      account_status DEFAULT 'active',
  gender              gender_type,
  age                 SMALLINT CHECK (age >= 18 AND age <= 100),
  city                VARCHAR(100),
  is_premium          BOOLEAN DEFAULT FALSE,
  premium_tier        premium_tier,
  premium_expires_at  TIMESTAMPTZ,
  is_onboarded        BOOLEAN DEFAULT FALSE,
  onboarding_step     SMALLINT DEFAULT 0,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  last_active         TIMESTAMPTZ DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ,
  device_fingerprints JSONB DEFAULT '[]'
);

CREATE INDEX idx_users_phone ON users(phone_hash);
CREATE INDEX idx_users_firebase ON users(firebase_uid);
CREATE INDEX idx_users_status ON users(account_status) WHERE account_status = 'active';
CREATE INDEX idx_users_last_active ON users(last_active DESC);
CREATE INDEX idx_users_gender_age ON users(gender, age) WHERE account_status = 'active';

-- ─── PROFILES ─────────────────────────────────────────────────────────

CREATE TABLE profiles (
  user_id                 UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  display_name            VARCHAR(30) NOT NULL,
  bio_prompt_responses    JSONB DEFAULT '[]',
  personality_tags        TEXT[] DEFAULT '{}',
  personality_vector      FLOAT[] DEFAULT '{}',
  voice_intro_url         VARCHAR(500),
  voice_transcript        TEXT,
  voice_sentiment_score   FLOAT CHECK (voice_sentiment_score BETWEEN -1 AND 1),
  photo_urls              TEXT[] DEFAULT '{}',
  photos_blurred          BOOLEAN DEFAULT TRUE,
  intent                  VARCHAR(50),
  trust_score             DECIMAL(5,2) DEFAULT 50.00 CHECK (trust_score BETWEEN 0 AND 100),
  creep_score             DECIMAL(5,2) DEFAULT 0.00 CHECK (creep_score BETWEEN 0 AND 100),
  profile_completeness    SMALLINT DEFAULT 0 CHECK (profile_completeness BETWEEN 0 AND 100),
  is_searchable           BOOLEAN DEFAULT TRUE,
  women_only_mode         BOOLEAN DEFAULT FALSE,
  ghost_mode              BOOLEAN DEFAULT FALSE,
  language_prefs          TEXT[] DEFAULT '{hindi_english}',
  updated_at              TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_profiles_trust ON profiles(trust_score DESC) WHERE is_searchable = TRUE;
CREATE INDEX idx_profiles_searchable ON profiles(is_searchable, women_only_mode, ghost_mode);
CREATE INDEX idx_profiles_tags ON profiles USING GIN(personality_tags);

-- ─── TRUST SCORE EVENTS ───────────────────────────────────────────────

CREATE TABLE trust_score_events (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  score_delta   DECIMAL(5,2) NOT NULL,
  reason        VARCHAR(100) NOT NULL,
  triggered_by  VARCHAR(50) DEFAULT 'system',
  metadata      JSONB DEFAULT '{}',
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_trust_events_user ON trust_score_events(user_id, created_at DESC);

-- ─── CONNECTIONS ──────────────────────────────────────────────────────

CREATE TABLE connections (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_a              UUID NOT NULL REFERENCES users(id),
  user_b              UUID NOT NULL REFERENCES users(id),
  status              connection_status DEFAULT 'connected',
  stage               SMALLINT DEFAULT 1 CHECK (stage BETWEEN 1 AND 5),
  initiated_by        UUID REFERENCES users(id),
  connected_at        TIMESTAMPTZ,
  last_message_at     TIMESTAMPTZ,
  name_revealed_at    TIMESTAMPTZ,
  photo_revealed_at   TIMESTAMPTZ,
  voice_call_at       TIMESTAMPTZ,
  stage_updated_at    TIMESTAMPTZ DEFAULT NOW(),
  message_count       INTEGER DEFAULT 0,
  is_disappearing     BOOLEAN DEFAULT FALSE,
  disappear_hours     SMALLINT DEFAULT 24,
  ai_suggestion       TEXT,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT no_self_connection CHECK (user_a != user_b),
  CONSTRAINT ordered_pair CHECK (user_a < user_b),
  CONSTRAINT unique_connection UNIQUE (user_a, user_b)
);

CREATE INDEX idx_connections_user_a ON connections(user_a, status, stage);
CREATE INDEX idx_connections_user_b ON connections(user_b, status, stage);
CREATE INDEX idx_connections_recent ON connections(last_message_at DESC) WHERE status = 'connected';
CREATE INDEX idx_connections_stage ON connections(stage) WHERE status = 'connected';

-- ─── SPARKS DELIVERED ─────────────────────────────────────────────────

CREATE TABLE sparks_delivered (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id),
  target_user_id    UUID NOT NULL REFERENCES users(id),
  action            VARCHAR(20) DEFAULT 'delivered',
  action_at         TIMESTAMPTZ,
  score_at_delivery DECIMAL(5,2),
  rank_position     SMALLINT,
  delivered_at      TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT unique_spark UNIQUE (user_id, target_user_id)
);

CREATE INDEX idx_sparks_user ON sparks_delivered(user_id, delivered_at DESC);
CREATE INDEX idx_sparks_action ON sparks_delivered(user_id, action);

-- ─── BLOCKS ───────────────────────────────────────────────────────────

CREATE TABLE blocks (
  blocker_id  UUID NOT NULL REFERENCES users(id),
  blocked_id  UUID NOT NULL REFERENCES users(id),
  reason      VARCHAR(100),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id)
);

CREATE INDEX idx_blocks_blocker ON blocks(blocker_id);
CREATE INDEX idx_blocks_blocked ON blocks(blocked_id);

-- ─── REPORTS ──────────────────────────────────────────────────────────

CREATE TABLE reports (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id       UUID NOT NULL REFERENCES users(id),
  reported_user_id  UUID NOT NULL REFERENCES users(id),
  reason            report_reason NOT NULL,
  note              TEXT,
  evidence_urls     TEXT[] DEFAULT '{}',
  status            report_status DEFAULT 'pending',
  assigned_to       VARCHAR(100),
  resolution_note   TEXT,
  resolved_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_reports_status ON reports(status, created_at ASC);
CREATE INDEX idx_reports_reported ON reports(reported_user_id);
CREATE INDEX idx_reports_reporter ON reports(reporter_id);

-- ─── ROOMS ────────────────────────────────────────────────────────────

CREATE TABLE rooms (
  id                         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name                       VARCHAR(100) NOT NULL,
  description                TEXT,
  emoji                      VARCHAR(10) DEFAULT '💬',
  type                       room_type NOT NULL,
  tags                       TEXT[] DEFAULT '{}',
  color                      VARCHAR(9) DEFAULT '#7A9E7E',
  language                   VARCHAR(30) DEFAULT 'hindi_english',
  member_count               INTEGER DEFAULT 0,
  post_count                 INTEGER DEFAULT 0,
  is_active                  BOOLEAN DEFAULT TRUE,
  is_featured                BOOLEAN DEFAULT FALSE,
  requires_verification      SMALLINT DEFAULT 1,
  women_only                 BOOLEAN DEFAULT FALSE,
  is_premium                 BOOLEAN DEFAULT FALSE,
  created_by                 UUID REFERENCES users(id),
  created_at                 TIMESTAMPTZ DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_rooms_type ON rooms(type) WHERE is_active = TRUE;
CREATE INDEX idx_rooms_featured ON rooms(is_featured, member_count DESC);
CREATE INDEX idx_rooms_women ON rooms(women_only) WHERE is_active = TRUE;

-- ─── ROOM MEMBERSHIPS ─────────────────────────────────────────────────

CREATE TABLE room_memberships (
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_id       UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  role          VARCHAR(20) DEFAULT 'member',
  post_count    INTEGER DEFAULT 0,
  last_active   TIMESTAMPTZ DEFAULT NOW(),
  joined_at     TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, room_id)
);

CREATE INDEX idx_memberships_user ON room_memberships(user_id);
CREATE INDEX idx_memberships_room ON room_memberships(room_id, last_active DESC);

-- ─── ROOM POSTS ───────────────────────────────────────────────────────

CREATE TABLE room_posts (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id             UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  author_id           UUID NOT NULL REFERENCES users(id),
  content             TEXT NOT NULL,
  is_anonymous        BOOLEAN DEFAULT FALSE,
  media_urls          TEXT[] DEFAULT '{}',
  reaction_counts     JSONB DEFAULT '{"❤️":0,"🔥":0,"💭":0,"😂":0}',
  reply_count         INTEGER DEFAULT 0,
  is_pinned           BOOLEAN DEFAULT FALSE,
  moderation_status   moderation_status DEFAULT 'approved',
  ai_toxicity_score   FLOAT DEFAULT 0,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_posts_room_time ON room_posts(room_id, created_at DESC) WHERE moderation_status = 'approved';
CREATE INDEX idx_posts_author ON room_posts(author_id);
CREATE INDEX idx_posts_search ON room_posts USING GIN(to_tsvector('english', content));

-- ─── TRUSTED CONTACTS ─────────────────────────────────────────────────

CREATE TABLE trusted_contacts (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        VARCHAR(100) NOT NULL,
  phone       VARCHAR(15) NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT max_contacts CHECK (
    (SELECT COUNT(*) FROM trusted_contacts tc WHERE tc.user_id = user_id) < 3
  )
);

CREATE INDEX idx_trusted_contacts_user ON trusted_contacts(user_id);

-- ─── SOS EVENTS ───────────────────────────────────────────────────────

CREATE TABLE sos_events (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id),
  latitude          DECIMAL(10, 7),
  longitude         DECIMAL(10, 7),
  contacts_alerted  SMALLINT DEFAULT 0,
  conversation_id   UUID REFERENCES connections(id),
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sos_user ON sos_events(user_id, created_at DESC);

-- ─── SUBSCRIPTIONS ────────────────────────────────────────────────────

CREATE TABLE subscriptions (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES users(id),
  tier                  premium_tier NOT NULL,
  billing_period        VARCHAR(10) DEFAULT 'monthly',
  amount_paise          INTEGER NOT NULL,
  razorpay_order_id     VARCHAR(100),
  razorpay_payment_id   VARCHAR(100),
  razorpay_sub_id       VARCHAR(100),
  status                VARCHAR(20) DEFAULT 'active',
  started_at            TIMESTAMPTZ DEFAULT NOW(),
  expires_at            TIMESTAMPTZ NOT NULL,
  cancelled_at          TIMESTAMPTZ,
  created_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_subs_user ON subscriptions(user_id, status);
CREATE INDEX idx_subs_expiry ON subscriptions(expires_at) WHERE status = 'active';

-- ─── MOOD CHECK-INS ───────────────────────────────────────────────────

CREATE TABLE mood_checkins (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id),
  mood        VARCHAR(10) NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mood_user_recent ON mood_checkins(user_id, created_at DESC);

-- ─── MODERATION LOG ───────────────────────────────────────────────────

CREATE TABLE moderation_log (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  moderator_id    VARCHAR(100) NOT NULL,
  action          VARCHAR(50) NOT NULL,
  target_type     VARCHAR(30) NOT NULL,
  target_id       UUID NOT NULL,
  reason          TEXT,
  metadata        JSONB DEFAULT '{}',
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_mod_log_target ON moderation_log(target_id, created_at DESC);
CREATE INDEX idx_mod_log_moderator ON moderation_log(moderator_id, created_at DESC);

-- ─── NOTIFICATIONS ────────────────────────────────────────────────────

CREATE TABLE notification_preferences (
  user_id               UUID PRIMARY KEY REFERENCES users(id),
  push_enabled          BOOLEAN DEFAULT TRUE,
  sparks_notify         BOOLEAN DEFAULT TRUE,
  messages_notify       BOOLEAN DEFAULT TRUE,
  rooms_notify          BOOLEAN DEFAULT TRUE,
  safety_notify         BOOLEAN DEFAULT TRUE,
  quiet_start_hour      SMALLINT DEFAULT 23,
  quiet_end_hour        SMALLINT DEFAULT 7,
  fcm_token             VARCHAR(500),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

-- ─── DEVICE SESSIONS ──────────────────────────────────────────────────

CREATE TABLE device_sessions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id),
  device_hash     VARCHAR(64) NOT NULL,
  platform        VARCHAR(10),
  app_version     VARCHAR(20),
  last_seen       TIMESTAMPTZ DEFAULT NOW(),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sessions_user ON device_sessions(user_id, last_seen DESC);
CREATE UNIQUE INDEX idx_sessions_device ON device_sessions(user_id, device_hash);

-- ─── TRIGGERS ─────────────────────────────────────────────────────────

-- Auto-update trust score when event is added
CREATE OR REPLACE FUNCTION update_trust_score()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE profiles
  SET trust_score = GREATEST(0, LEAST(100, trust_score + NEW.score_delta))
  WHERE user_id = NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_trust_score
AFTER INSERT ON trust_score_events
FOR EACH ROW EXECUTE FUNCTION update_trust_score();

-- Auto-update room member count
CREATE OR REPLACE FUNCTION update_room_member_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE rooms SET member_count = member_count + 1 WHERE id = NEW.room_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE rooms SET member_count = GREATEST(0, member_count - 1) WHERE id = OLD.room_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_room_member_count
AFTER INSERT OR DELETE ON room_memberships
FOR EACH ROW EXECUTE FUNCTION update_room_member_count();

-- Auto-update connection message count
CREATE OR REPLACE FUNCTION update_connection_stats()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE connections
  SET message_count = message_count + 1, last_message_at = NOW()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Soft delete users (DPDP compliance)
CREATE OR REPLACE FUNCTION soft_delete_user(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE users SET
    account_status = 'deleted',
    phone_hash = 'DELETED_' || p_user_id,
    email_hash = NULL,
    firebase_uid = NULL,
    deleted_at = NOW()
  WHERE id = p_user_id;

  UPDATE profiles SET
    display_name = 'Deleted User',
    bio_prompt_responses = '[]',
    voice_intro_url = NULL,
    photo_urls = '{}',
    is_searchable = FALSE
  WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- ─── SEED DATA ────────────────────────────────────────────────────────

INSERT INTO rooms (id, name, description, emoji, type, color, member_count, is_featured, women_only) VALUES
  (uuid_generate_v4(), 'Bollywood Unpopular Opinions', 'Hot takes welcome. Fights expected.', '🎬', 'interest', '#C4654A', 1247, TRUE, FALSE),
  (uuid_generate_v4(), 'Desi Women Talk', 'A safe space. Vent, share, support.', '🌸', 'women_only', '#7A9E7E', 892, FALSE, TRUE),
  (uuid_generate_v4(), 'First-gen Professionals', 'Corporate struggles and wins.', '💼', 'career', '#5B8DB8', 2103, TRUE, FALSE),
  (uuid_generate_v4(), 'Reading Circle: June', 'This month: Manto ki Kahaniyan.', '📚', 'activity', '#D4884A', 318, TRUE, FALSE),
  (uuid_generate_v4(), 'Startup Founders India', 'Building in public.', '🚀', 'career', '#4CAF79', 1678, FALSE, FALSE),
  (uuid_generate_v4(), 'Gentle Vent Space', 'Be kind. Listen first.', '🌧️', 'emotion', '#8B6BB1', 445, FALSE, FALSE),
  (uuid_generate_v4(), 'Hinglish Gang', 'Bhai/Behen log ek saath.', '🇮🇳', 'language', '#E8A030', 3201, TRUE, FALSE),
  (uuid_generate_v4(), 'Pune Night Owls', 'For those alive after midnight.', '🌙', 'city', '#5B8DB8', 543, FALSE, FALSE)
ON CONFLICT DO NOTHING;

-- ─── BLOCKS ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS blocks (
  blocker_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id),
  CONSTRAINT no_self_block CHECK (blocker_id != blocked_id)
);

-- ─── SPARKS DELIVERED ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sparks_delivered (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delivered_at    TIMESTAMPTZ DEFAULT NOW(),
  rank_position   SMALLINT,
  action          VARCHAR(20) DEFAULT 'pending',
  action_at       TIMESTAMPTZ,
  UNIQUE(user_id, target_user_id)
);
CREATE INDEX idx_sparks_user ON sparks_delivered(user_id, delivered_at DESC);

-- ─── MESSAGES ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  connection_id       UUID NOT NULL REFERENCES connections(id) ON DELETE CASCADE,
  sender_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content             TEXT NOT NULL,
  message_type        message_type DEFAULT 'text',
  moderation_status   moderation_status DEFAULT 'approved',
  is_read             BOOLEAN DEFAULT FALSE,
  reaction            VARCHAR(10),
  reply_to_id         UUID REFERENCES messages(id),
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ
);
CREATE INDEX idx_messages_connection ON messages(connection_id, created_at DESC);
CREATE INDEX idx_messages_sender ON messages(sender_id);

-- ─── REPORTS ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reports (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reporter_id       UUID NOT NULL REFERENCES users(id),
  reported_user_id  UUID NOT NULL REFERENCES users(id),
  reason            report_reason NOT NULL,
  note              TEXT,
  status            report_status DEFAULT 'pending',
  resolver_note     TEXT,
  resolved_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_reports_status ON reports(status, created_at ASC);

-- ─── TRUSTED CONTACTS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trusted_contacts (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        VARCHAR(100) NOT NULL,
  phone       VARCHAR(20) NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_trusted_contacts_user ON trusted_contacts(user_id);

-- ─── SOS EVENTS ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sos_events (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id),
  latitude          DECIMAL(10,7),
  longitude         DECIMAL(10,7),
  contacts_alerted  SMALLINT DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ─── ROOMS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rooms (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name              VARCHAR(100) NOT NULL,
  description       TEXT,
  room_type         room_type NOT NULL,
  city              VARCHAR(100),
  tags              TEXT[] DEFAULT '{}',
  cover_image_url   VARCHAR(500),
  member_count      INTEGER DEFAULT 0,
  post_count        INTEGER DEFAULT 0,
  is_active         BOOLEAN DEFAULT TRUE,
  created_by        UUID REFERENCES users(id),
  last_activity_at  TIMESTAMPTZ DEFAULT NOW(),
  created_at        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_rooms_type ON rooms(room_type, is_active);
CREATE INDEX idx_rooms_city ON rooms(city) WHERE is_active = TRUE;

-- ─── ROOM MEMBERS ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS room_members (
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_id    UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  joined_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, room_id)
);
CREATE INDEX idx_room_members_room ON room_members(room_id);

-- ─── ROOM POSTS ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS room_posts (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id             UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  author_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content             TEXT NOT NULL,
  post_type           VARCHAR(20) DEFAULT 'text',
  media_url           VARCHAR(500),
  poll_options        JSONB DEFAULT '[]',
  like_count          INTEGER DEFAULT 0,
  comment_count       INTEGER DEFAULT 0,
  moderation_status   moderation_status DEFAULT 'pending',
  created_at          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_room_posts_room ON room_posts(room_id, created_at DESC);

-- ─── PAYMENT ORDERS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payment_orders (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES users(id),
  razorpay_order_id     VARCHAR(100) UNIQUE NOT NULL,
  razorpay_payment_id   VARCHAR(100),
  plan_id               VARCHAR(50) NOT NULL,
  amount                INTEGER NOT NULL,
  status                VARCHAR(20) DEFAULT 'pending',
  paid_at               TIMESTAMPTZ,
  created_at            TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_payment_orders_user ON payment_orders(user_id, created_at DESC);

-- ─── ADMIN FLAG ────────────────────────────────────────────────────────
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- ─── SEED: Default Rooms ───────────────────────────────────────────────
INSERT INTO rooms (id, name, description, room_type, tags) VALUES
  (uuid_generate_v4(), 'Coffee & Conversations', 'Slow talks over virtual chai', 'interest', '{chai,casual,introvert}'),
  (uuid_generate_v4(), 'Women Safe Space', 'A room only for women — unfiltered and free', 'women_only', '{women,safe,support}'),
  (uuid_generate_v4(), 'Mumbai Connects', 'Find your Mumbai tribe', 'city', '{mumbai,local}'),
  (uuid_generate_v4(), 'Startup Founders', 'Connect with founders who build things', 'career', '{startup,tech,founder}'),
  (uuid_generate_v4(), 'Midnight Feelings', 'For the 2am thinkers', 'emotion', '{feelings,night,deep}')
ON CONFLICT DO NOTHING;
