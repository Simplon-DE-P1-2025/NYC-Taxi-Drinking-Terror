SELECT *
FROM {{ ref('daily_summary') }}
WHERE airport_trip_pct < 0
   OR airport_trip_pct > 100
