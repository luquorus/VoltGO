-- V133: Create notification system tables
-- Notification system for collaborators

-- 1. Push Tokens (FCM)
CREATE TABLE IF NOT EXISTS push_token (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    token TEXT NOT NULL,
    device_type VARCHAR(10) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(token)
);

CREATE INDEX IF NOT EXISTS idx_push_token_user ON push_token(user_id);

-- 2. Notification Preferences
CREATE TABLE IF NOT EXISTS notification_preference (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    category VARCHAR(20) NOT NULL,
    push_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    email_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    in_app_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    UNIQUE(user_id, category)
);

CREATE INDEX IF NOT EXISTS idx_notif_pref_user ON notification_preference(user_id);

-- 3. Collaborator Notifications
CREATE TABLE IF NOT EXISTS collaborator_notification (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL,
    type VARCHAR(50) NOT NULL,
    category VARCHAR(20) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    data_json JSONB,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    reference_id UUID,
    reference_type VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notification_recipient ON collaborator_notification(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notification_category ON collaborator_notification(category);
CREATE INDEX IF NOT EXISTS idx_notification_read ON collaborator_notification(is_read);
CREATE INDEX IF NOT EXISTS idx_notification_created_at ON collaborator_notification(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_recipient_created ON collaborator_notification(recipient_id, created_at DESC);
