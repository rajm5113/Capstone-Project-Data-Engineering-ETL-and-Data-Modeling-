-- One current row per song in the serving layer.
-- ingest_on is added by the upstream Glue songs transformation.

WITH ranked_songs AS (
    SELECT
        song_id,
        track_id,
        title,
        release,
        year,
        ROW_NUMBER() OVER (
            PARTITION BY song_id
            ORDER BY ingest_on DESC
        ) AS row_num
    FROM {{ source('deftunes_transform', 'songs') }}
    WHERE song_id IS NOT NULL
)

SELECT
    song_id,
    track_id,
    title,
    release,
    year
FROM ranked_songs
WHERE row_num = 1
