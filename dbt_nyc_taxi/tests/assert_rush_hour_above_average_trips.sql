-- Rush hour weekday slots must have more trips than the average weekday slot.
-- Rows returned = rush hour slots below average → flag or data is inconsistent.
WITH weekday_avg AS (
    SELECT AVG(total_trips) AS avg_trips
    FROM {{ ref('hourly_patterns') }}
    WHERE is_weekend = FALSE
)

SELECT h.*
FROM {{ ref('hourly_patterns') }} h
CROSS JOIN weekday_avg w
WHERE h.is_rush_hour = TRUE
  AND h.is_weekend = FALSE
  AND h.total_trips < w.avg_trips
