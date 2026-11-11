SELECT
    DATE_PART('year', fs.session_start_time) AS session_year,
    da.artist_name,
    SUM(fs.price) AS total_sales
FROM {{ var("target_schema") }}.fact_session AS fs
LEFT JOIN {{ var("target_schema") }}.dim_artists AS da
    ON fs.artist_id = da.artist_id
GROUP BY 1, 2
