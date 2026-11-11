-- Derive one current descriptive row per artist from the song catalogue.
WITH ranked_artists AS (
    SELECT
        artist_id,
        artist_mbid,
        artist_name,
        ROW_NUMBER() OVER (
            PARTITION BY artist_id
            ORDER BY ingest_on DESC, artist_name, artist_mbid
        ) AS row_num
    FROM {{ var("source_schema") }}.songs
    WHERE artist_id IS NOT NULL
)
SELECT
    artist_id,
    artist_mbid,
    artist_name
FROM ranked_artists
WHERE row_num = 1
