-- Enable the TimescaleDB extension (no-op if already enabled).
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Alert events table. Partitioned by created_at (server-side fire time).
-- Same caveat as telemetry_readings: hypertables disallow unique constraints
-- that omit the partitioning column, so there is no surrogate primary key.
-- Deduplication is enforced upstream by Redis.
CREATE TABLE IF NOT EXISTS alert_events (
    id         BIGSERIAL        NOT NULL,
    msg_id     VARCHAR(128)     NOT NULL,
    device_id  VARCHAR(64)      NOT NULL,
    sensor     VARCHAR(64)      NOT NULL,
    value      DOUBLE PRECISION NOT NULL,
    rule_name  VARCHAR(128),
    severity   VARCHAR(32),
    created_at TIMESTAMPTZ      NOT NULL
);

SELECT create_hypertable(
    'alert_events',
    'created_at',
    if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS idx_alert_device_time
    ON alert_events (device_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_alert_severity_time
    ON alert_events (severity, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_alert_msg_id
    ON alert_events (msg_id);
