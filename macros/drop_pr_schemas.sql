{#-
    Drop the schemas created by a CI run: <target.schema>, <target.schema>_silver and
    <target.schema>_gold. Refuses to run unless the target is `ci` and the schema is a
    per-PR schema (dbt_pr_*), so it can never drop dev or prod schemas.
-#}
{% macro drop_pr_schemas() %}

    {% if target.name != 'ci' or not target.schema.startswith('dbt_pr_') %}
        {{ exceptions.raise_compiler_error(
            "drop_pr_schemas only runs on target 'ci' with a dbt_pr_* schema (got target='"
            ~ target.name ~ "', schema='" ~ target.schema ~ "')"
        ) }}
    {% endif %}

    {% for suffix in ['', '_silver', '_gold'] %}
        {% set schema_name = target.schema ~ suffix %}
        {% do run_query('drop schema if exists ' ~ target.database ~ '.' ~ schema_name ~ ' cascade') %}
        {% do log('Dropped schema ' ~ target.database ~ '.' ~ schema_name, info=true) %}
    {% endfor %}

{% endmacro %}
