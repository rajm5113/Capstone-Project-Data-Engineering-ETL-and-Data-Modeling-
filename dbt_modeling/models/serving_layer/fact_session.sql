-- Grain: one row per song item within a user session.
-- The upstream Glue JSON job explodes session_items into individual rows.
-- Therefore session_id is not necessarily unique by itself.

SELECT
    session_id,
    user_id,
    song_id,
    artist_id,
    price,
    liked,
    liked_since,
    session_start_time
FROM {{ source('deftunes_transform', 'sessions') }}
