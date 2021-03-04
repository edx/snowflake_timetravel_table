-- Test changing the type of a column without altering the column count or names.
-- In this case, we changed col2 from a varchar(10) to a varchar(15).

{{ config(materialized='snowflake_timetravel_table') }}

select 1::int as col1, 'new'::varchar(15) as col2, 'values'::varchar(20) as col3
union all
select 2, 'new', 'values'
