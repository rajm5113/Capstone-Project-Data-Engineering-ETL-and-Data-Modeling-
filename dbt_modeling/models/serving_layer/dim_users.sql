-- One current row per user in the serving layer.
-- ingest_on is added by the upstream Glue JSON transformation.

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
            ORDER BY ingest_on DESC
        ) AS row_num
    FROM {{ source('deftunes_transform', 'users') }}
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
