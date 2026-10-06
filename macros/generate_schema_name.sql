{#- 
    Schema naming:
      - target `prod`: use the custom schema as-is (`silver`, `gold`).
      - any other target: `<target.schema>_<custom>` (e.g. `dbt_dev_silver`),
        so dev and CI runs never write into the production schemas.
      - no custom schema: fall back to the target schema.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}

    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}
