-- total_zone_activity = trips_as_origin + trips_as_destination (both >= 0),
-- so it must always be >= trips_as_origin.
-- Rows returned = arithmetic inconsistency in the model.
SELECT *
FROM {{ ref('zone_analysis') }}
WHERE total_zone_activity < trips_as_origin
