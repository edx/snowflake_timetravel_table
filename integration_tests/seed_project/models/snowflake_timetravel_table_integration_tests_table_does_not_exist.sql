{{
    config(
        materialized="table",
        post_hook="drop table if exists {{ this }}"
    )
}}
select 1 as doesnotmatter
