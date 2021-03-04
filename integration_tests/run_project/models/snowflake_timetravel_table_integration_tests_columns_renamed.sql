-- Test renaming columns without altering the column count or types.

{{ config(materialized='snowflake_timetravel_table') }}

select 1::int as col1, 'new'::varchar(10) as col2renamed, 'values'::varchar(20) as col3
union all
select 2, 'new', 'values'
