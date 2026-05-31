WITH booking_base AS (
    SELECT
        b.id,
        b.user_id,
        b.station_id,
        b.charger_unit_id,
        b.start_time,
        b.end_time,
        b.status,
        b.created_at,
        EXTRACT(HOUR FROM b.start_time) AS start_hour,
        EXTRACT(DOW FROM b.start_time) AS day_of_week,
        CAST((b.price_snapshot ->> 'amount') AS INTEGER) AS amount
    FROM booking b
),
station_meta AS (
    SELECT
        sv.station_id,
        sv.name AS station_name,
        sv.address,
        ST_Y(CAST(sv.location AS geometry)) AS station_lat,
        ST_X(CAST(sv.location AS geometry)) AS station_lng
    FROM station_version sv
    WHERE sv.workflow_status = 'PUBLISHED'
)
SELECT
    bb.id,
    bb.user_id,
    bb.station_id,
    sm.station_name,
    sm.address,
    sm.station_lat,
    sm.station_lng,
    bb.charger_unit_id,
    bb.start_time,
    bb.end_time,
    bb.status,
    bb.created_at,
    bb.start_hour,
    bb.day_of_week,
    bb.amount
FROM booking_base bb
LEFT JOIN station_meta sm ON sm.station_id = bb.station_id
ORDER BY bb.created_at DESC;
