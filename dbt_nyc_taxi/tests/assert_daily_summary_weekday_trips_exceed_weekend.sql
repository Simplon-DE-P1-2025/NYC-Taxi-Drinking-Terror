-- Monthly weekday trips should exceed monthly weekend trips.
-- Two reasons: (1) ~22 weekday dates vs ~9 weekend dates per month,
-- (2) Yellow Taxis serve primarily business commuters — mid-week demand
-- dominates since Uber/Lyft captured the weekend nightlife market.
-- Rows returned = months where weekday total <= weekend total → anomaly.
WITH weekday_vs_weekend AS (
    SELECT
        pickup_month,
        SUM(CASE WHEN is_weekend = FALSE THEN total_trips END) AS weekday_trips,
        SUM(CASE WHEN is_weekend = TRUE  THEN total_trips END) AS weekend_trips
    FROM {{ ref('daily_summary') }}
    GROUP BY pickup_month
)
SELECT *
FROM weekday_vs_weekend
WHERE weekday_trips <= weekend_trips
