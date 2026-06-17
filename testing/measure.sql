\echo '== Ukupno spremljenih redova =='
SELECT COUNT(*) AS total_stored FROM telemetry_readings;

\echo '== Jedinstveni msg_id (osnovica za gubitak) =='
SELECT COUNT(DISTINCT msg_id) AS unique_stored FROM telemetry_readings;

\echo '== Duplikati (mora biti prazno) =='
SELECT msg_id, COUNT(*) AS copies
FROM telemetry_readings
GROUP BY msg_id
HAVING COUNT(*) > 1
ORDER BY copies DESC
LIMIT 20;

\echo '== Latencija u zadnjih 5 minuta (ms) =='
SELECT
    ROUND(AVG(lat)::numeric, 1)                                           AS avg_ms,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY lat)::numeric, 1)  AS p50_ms,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY lat)::numeric, 1)  AS p95_ms,
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY lat)::numeric, 1)  AS p99_ms,
    COUNT(*)                                                              AS samples
FROM (
    SELECT EXTRACT(EPOCH FROM received_at) * 1000 - "timestamp" AS lat
    FROM telemetry_readings
    WHERE received_at > NOW() - INTERVAL '5 minutes'
) t;

\echo '== Propusnost (msg/s) =='
SELECT
    COUNT(*)                                                          AS rows,
    ROUND(EXTRACT(EPOCH FROM (MAX(received_at) - MIN(received_at)))::numeric, 1) AS span_s,
    ROUND((COUNT(*) / NULLIF(EXTRACT(EPOCH FROM (MAX(received_at) - MIN(received_at))), 0))::numeric, 1)
                                                                      AS throughput_msg_s
FROM telemetry_readings
WHERE received_at > NOW() - INTERVAL '5 minutes';

\echo '== Nadoknada nakon restarta (T5) =='
SELECT
    MIN(received_at)                                AS first_row,
    MAX(received_at)                                AS last_row,
    ROUND(EXTRACT(EPOCH FROM (MAX(received_at) - MIN(received_at)))::numeric, 1) AS span_s
FROM telemetry_readings
WHERE received_at > NOW() - INTERVAL '5 minutes';

\echo '== Redovi po uređaju / senzoru =='
SELECT device_id, sensor, COUNT(*) AS n
FROM telemetry_readings
GROUP BY device_id, sensor
ORDER BY device_id, sensor;

\echo '== Generirana upozorenja =='
SELECT severity, COUNT(*) AS n
FROM alert_events
GROUP BY severity
ORDER BY severity;
