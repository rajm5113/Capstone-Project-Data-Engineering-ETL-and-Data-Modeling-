SELECT
    DATE_PART('month', fs.session_start_time) AS session_month,
    DATE_PART('year', fs.session_start_time) AS session_year,
    du.country_code,
    SUM(fs.price) AS total_sales
FROM {{ var("target_schema") }}.fact_session AS fs
LEFT JOIN {{ var("target_schema") }}.dim_users AS du
    ON fs.user_id = du.user_id
GROUP BY 1, 2, 3
