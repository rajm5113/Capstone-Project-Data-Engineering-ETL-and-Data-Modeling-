-- The source table is incrementally appended by Glue. Keep one current row
-- per song for the serving dimension.
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
    FROM {{ var("source_schema") }}.songs
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
