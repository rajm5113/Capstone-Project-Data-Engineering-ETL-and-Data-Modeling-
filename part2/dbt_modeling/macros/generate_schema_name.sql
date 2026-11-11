{#
  The Coursera Superset instructions ask users to register the BI views from
  the exact schema name "deftunes_bi_views". dbt's default schema naming macro
  would prepend the profile schema (deftunes_serving), creating
  deftunes_serving_bi_views instead. Keep the serving tables in the profile
  schema and map the BI custom schema to the exact schema expected by the lab.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif custom_schema_name | trim == 'bi_views' -%}
        deftunes_bi_views
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
