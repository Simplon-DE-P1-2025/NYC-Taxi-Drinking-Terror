-- Manhattan should have more Yellow Taxi pickups than any other borough each month.
-- ~70% of NYC Yellow Taxi trips originate in Manhattan historically (TLC data).
-- Rows returned = months where another borough overtakes Manhattan → unexpected anomaly.
WITH monthly_borough AS (
    SELECT
        pickup_month,
        pickup_borough,
        SUM(total_trips) AS monthly_trips
    FROM {{ ref('daily_summary') }}
    WHERE pickup_borough IS NOT NULL
    GROUP BY pickup_month, pickup_borough
),
manhattan_vs_others AS (
    SELECT
        manhattan.pickup_month,
        manhattan.monthly_trips                AS manhattan_trips,
        MAX(others.monthly_trips)              AS max_other_borough_trips
    FROM monthly_borough AS manhattan
    JOIN monthly_borough AS others
        ON  manhattan.pickup_month   = others.pickup_month
        AND others.pickup_borough   != 'Manhattan'
    WHERE manhattan.pickup_borough = 'Manhattan'
    GROUP BY manhattan.pickup_month, manhattan.monthly_trips
)
SELECT *
FROM manhattan_vs_others
WHERE manhattan_trips <= max_other_borough_trips
