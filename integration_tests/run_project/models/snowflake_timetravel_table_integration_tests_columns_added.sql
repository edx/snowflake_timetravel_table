-- Test adding new columns.

{{ config(materialized='snowflake_timetravel_table') }}

select 1::int as col1, 'new'::varchar(10) as col2, 'values'::varchar(20) as col3, 3::int as newcol
union all
select 2, 'new', 'values', 4
