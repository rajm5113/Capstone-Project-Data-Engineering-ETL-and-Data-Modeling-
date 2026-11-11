-- The source table is incrementally appended by Glue. Keep one current row
-- per user for the serving dimension.
WITH ranked_users AS (
    SELECT
        user_id,
        user_lastname,
        user_name,
        user_since,
        place_name,
        country_code,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY ingest_on DESC, processing_timestamp DESC
        ) AS row_num
    FROM {{ var("source_schema") }}.users
    WHERE user_id IS NOT NULL
)
SELECT
    user_id,
    user_lastname,
    user_name,
    user_since,
    place_name,
    country_code
FROM ranked_users
WHERE row_num = 1
