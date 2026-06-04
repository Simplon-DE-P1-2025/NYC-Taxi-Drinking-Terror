WITH base AS (
    SELECT * FROM {{ ref('stg_yellow_trips') }}
),

aggregated AS (
    SELECT
        DATE_TRUNC('month', pickup_date)             AS pickup_month,
        pickup_hour,
        time_of_day,
        is_rush_hour,
        is_weekend,

        COUNT(*)                                     AS total_trips,
        SUM(passenger_count)                         AS total_passengers,
        ROUND(AVG(trip_distance_km), 2)              AS avg_distance_km,
        ROUND(AVG(trip_duration_minutes), 1)         AS avg_duration_min,
        ROUND(AVG(speed_kmh), 1)                     AS avg_speed_kmh,
        ROUND(AVG(fare_amount), 2)                   AS avg_fare,
        ROUND(AVG(fare_amount) / NULLIF(AVG(trip_distance_km), 0), 2) AS avg_fare_per_km,
        ROUND(AVG(total_amount), 2)                  AS avg_total_amount,
        ROUND(SUM(total_amount), 2)                  AS total_revenue,
        ROUND(
            AVG(CASE WHEN payment_type_id = 1 THEN tip_percentage END),
            2
        )                                            AS avg_tip_pct_card,
        COUNT(CASE WHEN is_airport_trip THEN 1 END)  AS airport_trips,
        ROUND(
            COUNT(CASE WHEN is_airport_trip THEN 1 END) * 100.0 / COUNT(*),
            2
        )                                            AS airport_trip_pct

    FROM base
    GROUP BY 1, 2, 3, 4, 5
)

SELECT * FROM aggregated
ORDER BY pickup_month, is_weekend, pickup_hour
