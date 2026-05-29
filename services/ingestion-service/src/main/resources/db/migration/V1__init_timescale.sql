-- Enable the TimescaleDB extension (no-op if already enabled).
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Telemetry readings table.
-- NOTE: Hypertables in TimescaleDB cannot have a UNIQUE constraint that omits
-- the partitioning column, so msg_id is NOT a primary key here. Deduplication
-- is handled exclusively in the application layer via Redis (see
-- DeduplicationService). The table is effectively append-only.
CREATE TABLE IF NOT EXISTS telemetry_readings (
    msg_id      VARCHAR(128)     NOT NULL,
    device_id   VARCHAR(64)      NOT NULL,
    sensor      VARCHAR(64)      NOT NULL,
    value       DOUBLE PRECISION NOT NULL,
    unit        VARCHAR(16),
    "timestamp" BIGINT,
    received_at TIMESTAMPTZ      NOT NULL
);

-- Convert the table into a hypertable partitioned by server-side receive time.
-- Chunks default to 7-day intervals; tune via chunk_time_interval if needed.
SELECT create_hypertable(
    'telemetry_readings',
    'received_at',
    if_not_exists => TRUE
);

-- Query-shape indexes (per-device and per-sensor time ranges).
CREATE INDEX IF NOT EXISTS idx_telemetry_device_time
    ON telemetry_readings (device_id, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_telemetry_sensor_time
    ON telemetry_readings (sensor, received_at DESC);

-- Non-unique lookup index on msg_id for debugging / forensic queries.
CREATE INDEX IF NOT EXISTS idx_telemetry_msg_id
    ON telemetry_readings (msg_id);
