WITH src AS (
    SELECT
        DATE_TRUNC('month', pickup_datetime) AS pickup_month,
        TO_DATE(pickup_datetime)             AS pickup_date,
        pickup_day_of_week,
        is_weekend,
        pickup_borough,
        passenger_count,
        trip_distance_km,
        trip_duration_minutes,
        fare_per_km,
        payment_type_id,
        tip_amount,
        tip_percentage,
        total_amount,
        is_airport_trip
    FROM {{ ref('stg_yellow_trips') }}
),
aggregated AS (
    SELECT
        pickup_month,
        pickup_date,
        pickup_day_of_week,
        is_weekend,
        pickup_borough,
        COUNT(*)                                                          AS total_trips,
        SUM(passenger_count)                                              AS total_passengers,
        ROUND(AVG(passenger_count), 2)                                    AS avg_nb_passengers,
        ROUND(AVG(trip_distance_km), 2)                                   AS avg_distance_km,
        ROUND(AVG(trip_duration_minutes), 1)                              AS avg_duration_min,
        ROUND(AVG(fare_per_km), 2)                                        AS avg_fare_per_km,
        ROUND(AVG(CASE WHEN payment_type_id = 1 THEN tip_amount END), 2) AS avg_tip_amount_card,
        ROUND(AVG(tip_percentage), 2)                                     AS avg_tip_pct_card,
        ROUND(AVG(total_amount), 2)                                       AS avg_total_amount,
        ROUND(SUM(total_amount), 2)                                       AS total_revenue,
        COUNT(CASE WHEN is_airport_trip THEN 1 END)                      AS airport_trips,
        ROUND(
            COUNT(CASE WHEN is_airport_trip THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0),
            2
        )                                                                  AS airport_trip_pct
    FROM src
    GROUP BY
        pickup_month,
        pickup_date,
        pickup_day_of_week,
        is_weekend,
        pickup_borough
)
SELECT
    pickup_month,
    pickup_date,
    pickup_day_of_week,
    is_weekend,
    pickup_borough,
    total_trips,
    total_passengers,
    avg_nb_passengers,
    avg_distance_km,
    avg_duration_min,
    avg_fare_per_km,
    avg_tip_amount_card,
    avg_tip_pct_card,
    avg_total_amount,
    total_revenue,
    airport_trips,
    airport_trip_pct
FROM aggregated
