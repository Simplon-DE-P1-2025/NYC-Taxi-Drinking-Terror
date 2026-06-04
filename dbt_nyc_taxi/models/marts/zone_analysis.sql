WITH base AS (
    SELECT * FROM {{ ref('stg_yellow_trips') }}
),

pickup_agg AS (
    SELECT
        pickup_location_id                           AS location_id,
        pickup_borough                               AS borough,
        pickup_zone                                  AS zone,
        pickup_service_zone                          AS service_zone,

        COUNT(*)                                     AS trips_as_origin,
        SUM(passenger_count)                         AS passengers_as_origin,
        ROUND(AVG(trip_distance_km), 2)              AS avg_trip_distance_km,
        ROUND(AVG(trip_duration_minutes), 1)         AS avg_trip_duration_min,
        ROUND(AVG(fare_amount), 2)                   AS avg_fare,
        ROUND(SUM(fare_amount) / NULLIF(SUM(trip_distance_km), 0), 2) AS avg_fare_per_km,
        ROUND(SUM(total_amount), 2)                  AS total_revenue_as_origin,
        COUNT(CASE WHEN is_airport_trip THEN 1 END)  AS airport_trips,
        ROUND(
            AVG(CASE WHEN payment_type_id = 1 THEN tip_percentage END),
            2
        )                                            AS avg_tip_pct_card

    FROM base
    WHERE pickup_location_id IS NOT NULL
    GROUP BY 1, 2, 3, 4
),

dropoff_agg AS (
    SELECT
        dropoff_location_id                          AS location_id,
        COUNT(*)                                     AS trips_as_destination,
        SUM(passenger_count)                         AS passengers_as_destination,
        ROUND(SUM(total_amount), 2)                  AS total_revenue_as_destination

    FROM base
    WHERE dropoff_location_id IS NOT NULL
    GROUP BY 1
),

final AS (
    SELECT
        p.location_id,
        p.borough,
        p.zone,
        p.service_zone,

        -- origin metrics
        p.trips_as_origin,
        p.passengers_as_origin,
        p.avg_trip_distance_km,
        p.avg_trip_duration_min,
        p.avg_fare,
        p.avg_fare_per_km,
        p.total_revenue_as_origin,
        p.airport_trips,
        p.avg_tip_pct_card,

        -- destination metrics
        COALESCE(d.trips_as_destination, 0)          AS trips_as_destination,
        COALESCE(d.passengers_as_destination, 0)     AS passengers_as_destination,
        COALESCE(d.total_revenue_as_destination, 0)  AS total_revenue_as_destination,

        -- combined activity
        p.trips_as_origin + COALESCE(d.trips_as_destination, 0) AS total_zone_activity

    FROM pickup_agg p
    LEFT JOIN dropoff_agg d ON p.location_id = d.location_id
)

SELECT * FROM final
ORDER BY total_zone_activity DESC
