-- Test what happens when no relation exists before running this model.

{{ config(materialized='snowflake_timetravel_table') }}

select 1::int as col1, 'new'::varchar(10) as col2, 'values'::varchar(20) as col3
union all
select 2, 'new', 'values'
