-- For each month, average trips during rush hours must exceed average trips
-- during non-rush hours on weekdays.
-- Rows returned = months where rush hours are not busier than off-peak → inconsistency.
WITH monthly_rush_vs_nonrush AS (
    SELECT
        pickup_month,
        AVG(CASE WHEN is_rush_hour = TRUE  THEN total_trips END) AS avg_rush_trips,
        AVG(CASE WHEN is_rush_hour = FALSE THEN total_trips END) AS avg_nonrush_trips
    FROM {{ ref('hourly_patterns') }}
    WHERE is_weekend = FALSE
    GROUP BY pickup_month
)

SELECT *
FROM monthly_rush_vs_nonrush
WHERE avg_rush_trips <= avg_nonrush_trips
