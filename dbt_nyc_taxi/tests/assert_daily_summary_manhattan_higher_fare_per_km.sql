-- Manhattan avg fare per km should exceed Bronx avg fare per km.
-- Manhattan traffic is among the slowest in the US: the meter ticks in time mode
-- at speeds below 12 mph, inflating the fare relative to distance covered.
-- Bronx trips use faster arterial roads (Grand Concourse, major avenues).
-- Rows returned = if Bronx fare/km >= Manhattan fare/km → data anomaly.
WITH borough_weighted_fare AS (
    SELECT
        pickup_borough,
        SUM(avg_fare_per_km * total_trips) / NULLIF(SUM(total_trips), 0) AS weighted_fare_per_km
    FROM {{ ref('daily_summary') }}
    WHERE pickup_borough IN ('Manhattan', 'Bronx')
    GROUP BY pickup_borough
)
SELECT *
FROM borough_weighted_fare
WHERE pickup_borough = 'Manhattan'
  AND weighted_fare_per_km <= (
      SELECT weighted_fare_per_km
      FROM borough_weighted_fare
      WHERE pickup_borough = 'Bronx'
  )
