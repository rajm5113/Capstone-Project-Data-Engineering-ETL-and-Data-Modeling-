SELECT
    song_id,
    track_id,
    title,
    release,
    year
FROM {{ var("source_schema") }}.songs
