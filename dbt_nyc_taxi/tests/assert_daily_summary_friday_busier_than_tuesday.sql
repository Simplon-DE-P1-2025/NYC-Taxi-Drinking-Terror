-- Fridays should generate more total trips than Tuesdays each month.
-- TGIF effect: after-work dinners, nightlife, and social travel push Friday volumes up.
-- This pattern is consistent across all NYC taxi datasets (TLC historical data).
-- Rows returned = months where Friday total <= Tuesday total → unexpected anomaly.
WITH day_trips_per_month AS (
    SELECT
        pickup_month,
        -- pickup_day_of_week: 0=Sunday, 1=Monday, ..., 5=Friday, 6=Saturday (Snowflake DAYOFWEEK)
        SUM(CASE WHEN pickup_day_of_week = 5 THEN total_trips END) AS friday_trips,
        SUM(CASE WHEN pickup_day_of_week = 2 THEN total_trips END) AS tuesday_trips
    FROM {{ ref('daily_summary') }}
    GROUP BY pickup_month
)
SELECT *
FROM day_trips_per_month
WHERE friday_trips <= tuesday_trips
