SELECT DISTINCT
    artist_id,
    artist_mbid,
    artist_name
FROM {{ var("source_schema") }}.songs
