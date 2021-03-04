{% macro relation_columns_different(first_relation_columns, second_relation_columns) -%}
  {#
    -- Compare the column quantity, order, names, and types between input relations.
    --
    -- This currently assumes that the given column lists are sorted by ordinal position.  The result of
    -- get_columns_in_relation() is expected to be fed to this macro, which uses Snowflake's DESCRIBE TABLE under the
    -- hood; however, the DESCRIBE TABLE docs don't clearly state how the output is ordered.
    --
    -- Args:
    --   first_relation_columns (list of dict):
    --     List of column details for the first relation, in the form returned by adapter.get_columns_in_relation().
    --   second_relation_columns (list of dict): List of column details for the second relation.
    --
    -- Returns (bool): True if the columns from the first relation are different than those of the second relation.
  #}
  {%- set ns = namespace() -%}
  {%- set ns.different = false -%}
  {%- if first_relation_columns|length != second_relation_columns|length -%}
    {%- set ns.different = true -%}
  {%- else -%}
    {# -- Compare column names and types from both relations, sensitive to ordinal position. #}
    {%- for item in first_relation_columns -%}
      {# -- loop.index starts at 1 instead of 0, however jinja lists are 0-indexed (whyyy) so we have to subtract 1. #}
      {%- if item.name != second_relation_columns[loop.index-1].name
          or item.data_type != second_relation_columns[loop.index-1].data_type -%}
        {%- set ns.different = true -%}
        {# -- Typically I would want to "break" out of the for-loop here, but Jinja2 loops cannot "break". Logically,
           -- this should not be a problem. #}
      {%- endif -%}
    {%- endfor -%}
  {%- endif -%}
  {%- do return(ns.different) -%}
{%- endmacro %}


{% macro get_truncate_insert_sql(target_relation, sql, dest_columns) -%}
  {#
    -- Get the SQL for truncating and inserting the results of a select statement into a target relation with known
    -- columns.
    --
    -- Args:
    --   target_relation: The relation to insert into.
    --   sql (str): The SQL of the select statement in question, where columns match dest_columns.
    --   dest_columns (list of dict):
    --     List of column details for the relation, in the form returned by adapter.get_columns_in_relation().
  #}
  truncate table {{ target_relation }};
  {%- set dest_cols_csv = get_quoted_csv(dest_columns | map(attribute="name")) -%}
  insert into {{ target_relation }} ({{ dest_cols_csv }})
  (
    {{ sql }}
  );
{%- endmacro %}


{% materialization snowflake_timetravel_table, adapter='snowflake' %}
  {#
    -- A custom table materialization which supports time travel.
    --
    -- This is based on the existing "table" materialization part of dbt core, but adds a special case: when there is no
    -- change in the columns (i.e. the table schema) introduced by the model SQL, perform a truncate+insert instead of
    -- the default replace (i.e. create or replace).
  #}

  {% set original_query_tag = set_query_tag() %}

  {%- set identifier = model['alias'] -%}

  {%- set old_relation = adapter.get_relation(database=database, schema=schema, identifier=identifier) -%}
  {%- set target_relation = api.Relation.create(identifier=identifier,
                                                schema=schema,
                                                database=database, type='table') -%}

  {{ run_hooks(pre_hooks, inside_transaction=False) }}

  -- `BEGIN` happens here:
  {{ run_hooks(pre_hooks, inside_transaction=True) }}

  {% if old_relation is none %}
      {% set build_sql = create_table_as(false, target_relation, sql) %}
  {% else %}
    {% if not old_relation.is_table %}
      {#-- Drop the relation if it was a view to "convert" it in a table. This may lead to
        -- downtime, but it should be a relatively infrequent occurrence  #}
      {{ log("Dropping relation " ~ old_relation ~ " because it is of type " ~ old_relation.type) }}
      {{ drop_relation_if_exists(old_relation) }}
      {% set build_sql = create_table_as(false, target_relation, sql) %}
    {% else %}
      {# -- The table pre-existed, so now we try to detect if there were any column changes in the new SQL. #}
      {# -- create temp view for comparison of columns #}
      {% set tmp_relation = make_temp_relation(this) %}
      {# -- If we don't fill in the type now, then later when we call adapter.drop_relation(tmp_relation) it will not
         -- know whether to drop it as a table or a view. #}
      {% set tmp_relation = tmp_relation.incorporate(type='view') %}
      {# -- Aside: {% do something %} vs. {{ something }}: The former immediately executes without rendering the results
         -- to the compiled output, and the latter will be rendered into the compiled output where it will later run
         -- inside a transaction.  Use `do` if it doesn't ever need to be rolled back and doesn't touch the target
         -- relation. #}
      {% do run_query(create_view_as(tmp_relation, sql)) %}
      {# -- compare old relation columns with temp view columns #}
      {% set old_columns = adapter.get_columns_in_relation(target_relation) %}
      {% set new_columns = adapter.get_columns_in_relation(tmp_relation) %}
      {% set changed = snowflake_timetravel_table.relation_columns_different(old_columns, new_columns) %}
      {# -- drop temp view since we don't need it anymore #}
      {% do adapter.drop_relation(tmp_relation) %}
      {% if changed %}
        {# -- Revert back to the default table materialization implementation since the columns have changed. #}
        {% set build_sql = create_table_as(false, target_relation, sql) %}
      {% else %}
        {# -- The new model SQL does not change the columns so we can preserve time travel history by using the
           -- truncate+insert method. #}
        {% set build_sql = snowflake_timetravel_table.get_truncate_insert_sql(target_relation, sql, old_columns) %}
      {% endif %}
    {% endif %}
  {% endif %}

  --build model
  {% call statement('main') -%}
    {{ build_sql }}
  {%- endcall %}

  {{ run_hooks(post_hooks, inside_transaction=True) }}

  -- `COMMIT` happens here
  {{ adapter.commit() }}

  {{ run_hooks(post_hooks, inside_transaction=False) }}

  {% do persist_docs(target_relation, model) %}

  {% do unset_query_tag(original_query_tag) %}

  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
