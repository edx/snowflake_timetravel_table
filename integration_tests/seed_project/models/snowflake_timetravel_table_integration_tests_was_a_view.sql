{{
    config(materialized="view")
}}
select 1::int as col1, 'old'::varchar(10) as col2, 'values'::varchar(20) as col3
union all
select 2, 'old', 'values'
