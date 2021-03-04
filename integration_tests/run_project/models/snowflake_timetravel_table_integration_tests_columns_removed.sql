-- Test removing columns.

{{ config(materialized='snowflake_timetravel_table') }}

select 1::int as col1, 'new'::varchar(10) as col2
union all
select 2, 'new'
