# DeFtunes dbt models

This project builds the DeFtunes serving-layer star schema in Amazon Redshift.

## Source and target

- **Source schema:** `deftunes_transform`, exposed in Redshift by Redshift Spectrum from the Glue Catalog / Iceberg transformation zone.
- **Target schema:** `deftunes_serving`, configured in the local `~/.dbt/profiles.yml` profile.
- **Database:** `dev` in the Coursera lab environment.
- **Adapter:** `dbt-redshift`.

The source tables are declared in `models/sources.yml`. SQL models use dbt's `source()` function so the upstream schema is explicit and does not need to be hard-coded into each query.

## Models

| Model | Type | Description |
|---|---|---|
| `dim_users` | Dimension | Latest user profile attributes. |
| `dim_songs` | Dimension | Latest song catalogue attributes. |
| `dim_artists` | Dimension | Artist identifiers and descriptive attributes from the song catalogue. |
| `fact_session` | Fact | Session-item activity, including user, song, artist, price, like status and start time. |

The upstream Glue JSON transformation explodes `session_items` into individual rows. Consequently, `fact_session` is at **session-item grain**, and `session_id` can appear more than once. Its schema tests intentionally check that `session_id` is present, not unique.

Dimension models use `ingest_on` to retain the latest row for each business key when the source table contains multiple ingestion batches.

## Run in the lab environment

First configure the local profile using `../scripts/profiles.yml.example`. Replace the endpoint, username and password with values from the current AWS lab environment. Do not commit the real profile.

From this directory:

```bash
dbt debug
dbt run -s serving_layer
dbt test -s serving_layer
```

After a successful run, inspect the output tables in Redshift:

```sql
SHOW TABLES FROM SCHEMA dev.deftunes_serving;

SELECT * FROM deftunes_serving.dim_users LIMIT 10;
SELECT * FROM deftunes_serving.dim_songs LIMIT 10;
SELECT * FROM deftunes_serving.dim_artists LIMIT 10;
SELECT * FROM deftunes_serving.fact_session LIMIT 10;
```

Run the project only after the upstream Glue transformations have completed and the `users`, `songs` and `sessions` external tables are available in `deftunes_transform`.

## Assignment context

The original Part 1 notebook describes the star-schema modeling exercise as optional and not graded. This repository includes the implementation as a portfolio extension, using the source fields created by the lab's Glue transformations. The separate `part2/dbt_modeling` project contains the later BI views as well.
