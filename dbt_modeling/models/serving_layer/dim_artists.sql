-- One current descriptive record per artist, derived from the song catalogue.
-- ingest_on is added by the upstream Glue songs transformation.

WITH ranked_artists AS (
    SELECT
        artist_id,
        artist_mbid,
        artist_name,
        ROW_NUMBER() OVER (
            PARTITION BY artist_id
            ORDER BY ingest_on DESC
        ) AS row_num
    FROM {{ source('deftunes_transform', 'songs') }}
    WHERE artist_id IS NOT NULL
)

SELECT
    artist_id,
    artist_mbid,
    artist_name
FROM ranked_artists
WHERE row_num = 1
