-- New Year's Eve (Dec 31) should have more total pickups than the average December day.
-- NYC taxis historically peak on NYE due to nightlife demand.
-- Rows returned = years where NYE is not above the December daily average → data anomaly.
WITH december_days AS (
    SELECT
        YEAR(pickup_date) AS pickup_year,
        pickup_date,
        SUM(total_trips)  AS day_trips
    FROM {{ ref('daily_summary') }}
    WHERE MONTH(pickup_date) = 12
    GROUP BY YEAR(pickup_date), pickup_date
),
stats AS (
    SELECT
        pickup_year,
        AVG(CASE WHEN DAY(pickup_date) != 31 THEN day_trips END) AS avg_december_trips,
        MAX(CASE WHEN DAY(pickup_date) = 31 THEN day_trips END)  AS nye_trips
    FROM december_days
    GROUP BY pickup_year
)
SELECT *
FROM stats
WHERE nye_trips IS NOT NULL
  AND nye_trips <= avg_december_trips
