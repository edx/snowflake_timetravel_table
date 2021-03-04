
select *
from {{ ref('snowflake_timetravel_table_integration_tests_columns_no_change') }}
at (timestamp => '{{ env_var("TIMESTAMP_BEFORE_TRUNCATE_INSERT", "ERROR") }}'::timestamp_tz)
where col2 = 'new'
