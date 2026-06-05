WITH base AS (
    SELECT *
    FROM {{ ref('stg_yellow_trips') }}
),
aggregated AS (
    SELECT
        DATE_TRUNC('month', pickup_datetime)     AS pickup_month,
        TO_DATE(pickup_datetime)                 AS pickup_date,
        pickup_day_of_week,
        is_weekend,
        pickup_borough,
        dropoff_borough,
        duration_category,
        COUNT(*)                                 AS total_trips,
        SUM(passenger_count)                     AS total_passengers,
        ROUND(AVG(passenger_count), 2)           AS avg_nb_passengers,
        ROUND(AVG(trip_distance_km), 2)          AS avg_distance_km,
        ROUND(AVG(trip_duration_minutes), 1)     AS avg_duration_min,
        ROUND(AVG(fare_per_km), 2)               AS avg_fare_per_km,
        ROUND(AVG(tip_amount), 2)                AS avg_tip_amount,
        ROUND(AVG(tip_percentage), 2)            AS avg_tip_percentage,
        ROUND(AVG(total_amount), 2)              AS avg_total_amount,
        ROUND(SUM(total_amount), 2)              AS total_revenue,
        COUNT(CASE WHEN is_airport_trip THEN 1 END) AS airport_trips,
        ROUND(
            COUNT(CASE WHEN is_airport_trip THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0),
            2
        ) AS airport_trip_pct
    FROM base
    GROUP BY 1, 2, 3, 4, 5, 6, 7
)
SELECT *
FROM aggregated
ORDER BY pickup_date, pickup_borough, dropoff_borough, duration_category