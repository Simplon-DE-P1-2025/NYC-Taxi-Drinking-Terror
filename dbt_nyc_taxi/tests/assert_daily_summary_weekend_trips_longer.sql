-- Weekend trips should cover more km on average than weekday trips each month.
-- Weekday trips are dominated by short intra-Manhattan commutes.
-- Weekend trips skew longer: airports, outer boroughs, leisure travel.
-- Rows returned = months where weekday avg distance >= weekend avg distance → unexpected.
WITH weekend_vs_weekday AS (
    SELECT
        pickup_month,
        AVG(CASE WHEN is_weekend = TRUE  THEN avg_distance_km END) AS weekend_avg_km,
        AVG(CASE WHEN is_weekend = FALSE THEN avg_distance_km END) AS weekday_avg_km
    FROM {{ ref('daily_summary') }}
    GROUP BY pickup_month
)
SELECT *
FROM weekend_vs_weekday
WHERE weekend_avg_km <= weekday_avg_km
