-- Migration: 001_initial_schema
-- Run: node-pg-migrate up (with DATABASE_URL set)
BEGIN;

CREATE TABLE IF NOT EXISTS users (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone_hash          VARCHAR(64) NOT NULL UNIQUE,
  firebase_uid        VARCHAR(128) UNIQUE,
  fcm_token           TEXT,
  verification_level  SMALLINT NOT NULL DEFAULT 1,
  kyc_level           VARCHAR(20),
  account_status      VARCHAR(20) NOT NULL DEFAULT 'active'
                        CHECK (account_status IN ('active','suspended','banned','deactivated')),
  gender              VARCHAR(20),
  age                 SMALLINT,
  city                VARCHAR(100),
  is_onboarded        BOOLEAN NOT NULL DEFAULT false,
  is_premium          BOOLEAN NOT NULL DEFAULT false,
  premium_tier        VARCHAR(20),
  premium_expires_at  TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_active         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS profiles (
  user_id               UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  display_name          VARCHAR(50),
  bio_prompt_responses  JSONB NOT NULL DEFAULT '[]',
  personality_tags      TEXT[] NOT NULL DEFAULT '{}',
  intent                VARCHAR(50),
  voice_intro_url       TEXT,
  photo_urls            TEXT[] NOT NULL DEFAULT '{}',
  photos_blurred        BOOLEAN NOT NULL DEFAULT true,
  trust_score           SMALLINT NOT NULL DEFAULT 50,
  profile_completeness  SMALLINT NOT NULL DEFAULT 0,
  is_searchable         BOOLEAN NOT NULL DEFAULT false,
  ghost_mode            BOOLEAN NOT NULL DEFAULT false,
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS connections (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status        VARCHAR(20) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','connected','blocked','ended','flagged')),
  stage         SMALLINT NOT NULL DEFAULT 1 CHECK (stage BETWEEN 1 AND 5),
  initiated_by  UUID REFERENCES users(id),
  connected_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_a, user_b),
  CHECK (user_a < user_b)
);

CREATE TABLE IF NOT EXISTS sparks_delivered (
  id              BIGSERIAL PRIMARY KEY,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delivered_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  rank_position   SMALLINT,
  action          VARCHAR(20) CHECK (action IN ('pending','connect','pass','save')),
  action_at       TIMESTAMPTZ,
  UNIQUE (user_id, target_user_id)
);

CREATE TABLE IF NOT EXISTS rooms (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          VARCHAR(100) NOT NULL,
  description   TEXT,
  emoji         VARCHAR(10) NOT NULL DEFAULT '💬',
  color         VARCHAR(30) NOT NULL DEFAULT 'rose',
  category      VARCHAR(50),
  cover_url     TEXT,
  created_by    UUID REFERENCES users(id),
  is_public     BOOLEAN NOT NULL DEFAULT true,
  member_count  INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS room_members (
  room_id   UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  role      VARCHAR(20) NOT NULL DEFAULT 'member',
  PRIMARY KEY (room_id, user_id)
);

CREATE TABLE IF NOT EXISTS trusted_contacts (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name       VARCHAR(100) NOT NULL,
  phone      VARCHAR(20) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS blocks (
  blocker_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (blocker_id, blocked_id)
);

CREATE TABLE IF NOT EXISTS reports (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_user_id  UUID REFERENCES users(id) ON DELETE SET NULL,
  reason            VARCHAR(50) NOT NULL,
  note              TEXT,
  status            VARCHAR(20) NOT NULL DEFAULT 'pending',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sos_events (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  latitude         DOUBLE PRECISION,
  longitude        DOUBLE PRECISION,
  contacts_alerted SMALLINT NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orders (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  razorpay_order_id   VARCHAR(100) UNIQUE,
  razorpay_payment_id VARCHAR(100),
  amount_paise        INTEGER NOT NULL,
  currency            VARCHAR(10) NOT NULL DEFAULT 'INR',
  status              VARCHAR(20) NOT NULL DEFAULT 'created',
  plan                VARCHAR(50),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  paid_at             TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_users_phone_hash     ON users(phone_hash);
CREATE INDEX IF NOT EXISTS idx_users_last_active     ON users(last_active DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_trust_score  ON profiles(trust_score DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_searchable   ON profiles(is_searchable) WHERE is_searchable = true;
CREATE INDEX IF NOT EXISTS idx_sparks_user_date      ON sparks_delivered(user_id, delivered_at DESC);
CREATE INDEX IF NOT EXISTS idx_connections_user_a    ON connections(user_a);
CREATE INDEX IF NOT EXISTS idx_connections_user_b    ON connections(user_b);
CREATE INDEX IF NOT EXISTS idx_room_members_user     ON room_members(user_id);

COMMIT;
