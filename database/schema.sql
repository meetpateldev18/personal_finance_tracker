-- ============================================================
-- Personal Finance Tracker — PostgreSQL 15 Schema
-- ============================================================
-- Run: psql -U financeuser -d financedb -f schema.sql
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- USERS & AUTHENTICATION
-- ============================================================

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cognito_sub     VARCHAR(255) UNIQUE,                          -- AWS Cognito subject
    email           VARCHAR(255) NOT NULL UNIQUE,
    username        VARCHAR(100) NOT NULL UNIQUE,
    full_name       VARCHAR(255) NOT NULL,
    phone_number    VARCHAR(20),
    avatar_url      VARCHAR(500),                                 -- S3 URL
    currency        VARCHAR(3) NOT NULL DEFAULT 'USD',
    timezone        VARCHAR(50) NOT NULL DEFAULT 'UTC',
    monthly_income  DECIMAL(15,2) DEFAULT 0.00,
    role            VARCHAR(20) NOT NULL DEFAULT 'USER'           -- USER, ADMIN, FAMILY_ADMIN
        CHECK (role IN ('USER', 'ADMIN', 'FAMILY_ADMIN')),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_info     VARCHAR(500),
    ip_address      INET,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    last_active_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE refresh_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token_hash      VARCHAR(255) NOT NULL UNIQUE,                 -- bcrypt hash of actual token
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id      UUID REFERENCES sessions(id) ON DELETE SET NULL,
    expires_at      TIMESTAMPTZ NOT NULL,
    is_revoked      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Track failed login attempts for security
CREATE TABLE login_attempts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) NOT NULL,
    ip_address      INET,
    success         BOOLEAN NOT NULL,
    attempted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- CATEGORIES & TAGS
-- ============================================================

CREATE TABLE categories (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,  -- NULL = system-wide default
    name            VARCHAR(100) NOT NULL,
    icon            VARCHAR(50),                                  -- emoji or icon name
    color           VARCHAR(7),                                   -- hex color
    type            VARCHAR(10) NOT NULL CHECK (type IN ('INCOME', 'EXPENSE', 'BOTH')),
    is_default      BOOLEAN NOT NULL DEFAULT FALSE,               -- system default category
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed default categories
INSERT INTO categories (name, icon, color, type, is_default) VALUES
('Salary',          '💼', '#4CAF50', 'INCOME',  TRUE),
('Freelance',       '💻', '#8BC34A', 'INCOME',  TRUE),
('Investment',      '📈', '#00BCD4', 'INCOME',  TRUE),
('Food & Dining',   '🍔', '#FF9800', 'EXPENSE', TRUE),
('Transportation',  '🚗', '#607D8B', 'EXPENSE', TRUE),
('Shopping',        '🛍️',  '#E91E63', 'EXPENSE', TRUE),
('Utilities',       '💡', '#FFC107', 'EXPENSE', TRUE),
('Healthcare',      '🏥', '#F44336', 'EXPENSE', TRUE),
('Entertainment',   '🎬', '#9C27B0', 'EXPENSE', TRUE),
('Housing',         '🏠', '#3F51B5', 'EXPENSE', TRUE),
('Education',       '📚', '#009688', 'EXPENSE', TRUE),
('Travel',          '✈️',  '#FF5722', 'EXPENSE', TRUE),
('Other',           '📦', '#9E9E9E', 'BOTH',    TRUE);

CREATE TABLE tags (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            VARCHAR(50) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, name)
);

-- ============================================================
-- TRANSACTIONS
-- ============================================================

CREATE TABLE transactions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id     UUID REFERENCES categories(id) ON DELETE SET NULL,
    type            VARCHAR(10) NOT NULL CHECK (type IN ('INCOME', 'EXPENSE', 'TRANSFER')),
    amount          DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    currency        VARCHAR(3) NOT NULL DEFAULT 'USD',
    description     VARCHAR(500),
    merchant        VARCHAR(255),
    receipt_url     VARCHAR(500),                                 -- S3 URL
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_recurring    BOOLEAN NOT NULL DEFAULT FALSE,
    recurrence_rule VARCHAR(100),                                 -- iCal RRULE format
    location        VARCHAR(255),
    notes           TEXT,
    is_flagged      BOOLEAN NOT NULL DEFAULT FALSE,               -- fraud/unusual flag
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Many-to-many: transactions ↔ tags
CREATE TABLE transaction_tags (
    transaction_id  UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    tag_id          UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (transaction_id, tag_id)
);

-- ============================================================
-- BUDGETS
-- ============================================================

CREATE TABLE budgets (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id         UUID REFERENCES categories(id) ON DELETE SET NULL,
    name                VARCHAR(100) NOT NULL,
    amount              DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    spent_amount        DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    period              VARCHAR(20) NOT NULL DEFAULT 'MONTHLY'
        CHECK (period IN ('WEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY')),
    start_date          DATE NOT NULL,
    end_date            DATE NOT NULL,
    alert_threshold_pct INTEGER NOT NULL DEFAULT 80
        CHECK (alert_threshold_pct BETWEEN 1 AND 100),
    large_tx_threshold  DECIMAL(15,2),                           -- alert on single tx above this
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    rollover_unused     BOOLEAN NOT NULL DEFAULT FALSE,           -- roll leftover to next period
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (end_date > start_date)
);

CREATE TABLE budget_alerts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id       UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    alert_type      VARCHAR(30) NOT NULL
        CHECK (alert_type IN ('THRESHOLD', 'EXCEEDED', 'LARGE_TRANSACTION', 'RESET', 'WEEKLY_SUMMARY')),
    threshold_pct   INTEGER,                                     -- which % triggered this
    message         TEXT NOT NULL,
    is_sent         BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SLACK INTEGRATION
-- ============================================================

CREATE TABLE slack_integrations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    slack_user_id       VARCHAR(100),                            -- Slack user ID (U...)
    slack_team_id       VARCHAR(100),                            -- Slack workspace ID
    slack_channel_id    VARCHAR(100),                            -- DM or channel for alerts
    access_token        VARCHAR(500),                            -- Encrypted Slack token
    bot_token           VARCHAR(500),                            -- Encrypted bot token
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    connected_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE notification_preferences (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    slack_budget_alerts         BOOLEAN NOT NULL DEFAULT TRUE,
    slack_large_tx_alerts       BOOLEAN NOT NULL DEFAULT TRUE,
    slack_daily_summary         BOOLEAN NOT NULL DEFAULT FALSE,
    slack_weekly_report         BOOLEAN NOT NULL DEFAULT TRUE,
    slack_monthly_reset         BOOLEAN NOT NULL DEFAULT TRUE,
    daily_summary_time          TIME DEFAULT '21:00:00',         -- time to send daily summary
    weekly_report_day           INTEGER DEFAULT 0                -- 0=Sunday
        CHECK (weekly_report_day BETWEEN 0 AND 6),
    large_tx_threshold          DECIMAL(15,2) DEFAULT 500.00,
    push_notifications          BOOLEAN NOT NULL DEFAULT TRUE,
    email_notifications         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- AI INSIGHTS
-- ============================================================

CREATE TABLE ai_insights (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    insight_type        VARCHAR(50) NOT NULL
        CHECK (insight_type IN ('SPENDING_ANALYSIS', 'BUDGET_RECOMMENDATION',
                                'UNUSUAL_SPENDING', 'MONTHLY_HEALTH', 'CUSTOM_QUERY')),
    period_start        DATE,
    period_end          DATE,
    prompt_tokens       INTEGER,
    completion_tokens   INTEGER,
    raw_prompt          TEXT,
    raw_response        TEXT NOT NULL,
    summary             VARCHAR(500),                            -- short extracted summary
    is_read             BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE financial_scores (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    score               INTEGER NOT NULL CHECK (score BETWEEN 0 AND 100),
    month               DATE NOT NULL,                           -- first day of month
    breakdown           JSONB NOT NULL DEFAULT '{}',             -- per-category breakdown
    explanation         TEXT NOT NULL,
    recommendations     TEXT[],
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, month)
);

-- ============================================================
-- INDEXES for performance
-- ============================================================

CREATE INDEX idx_transactions_user_id       ON transactions(user_id);
CREATE INDEX idx_transactions_category_id   ON transactions(category_id);
CREATE INDEX idx_transactions_date          ON transactions(transaction_date DESC);
CREATE INDEX idx_transactions_user_date     ON transactions(user_id, transaction_date DESC);
CREATE INDEX idx_transactions_type          ON transactions(type);

CREATE INDEX idx_budgets_user_id            ON budgets(user_id);
CREATE INDEX idx_budgets_category_id        ON budgets(category_id);
CREATE INDEX idx_budgets_active             ON budgets(user_id, is_active);

CREATE INDEX idx_budget_alerts_budget_id    ON budget_alerts(budget_id);
CREATE INDEX idx_budget_alerts_user_sent    ON budget_alerts(user_id, is_sent);

CREATE INDEX idx_sessions_user_id           ON sessions(user_id);
CREATE INDEX idx_refresh_tokens_user_id     ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_hash        ON refresh_tokens(token_hash);

CREATE INDEX idx_ai_insights_user_id        ON ai_insights(user_id);
CREATE INDEX idx_ai_insights_type           ON ai_insights(user_id, insight_type);

CREATE INDEX idx_login_attempts_email_time  ON login_attempts(email, attempted_at DESC);

-- ============================================================
-- UPDATED_AT trigger function
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_transactions_updated_at
    BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_budgets_updated_at
    BEFORE UPDATE ON budgets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_slack_integrations_updated_at
    BEFORE UPDATE ON slack_integrations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_notification_preferences_updated_at
    BEFORE UPDATE ON notification_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
