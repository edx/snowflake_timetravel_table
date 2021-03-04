# snowflake_timetravel_table dbt package

This dbt package provides a custom Snowflake dbt materialization meant to be
used in place of the standard "table" materialization, adding some support for
Snowflake Time Travel on the output tables.  It is based on the existing
"table" snowflake materialization, however it enables the use of Time Travel by
avoiding table drops.

This materialization will still drop a table (thereby deleting time travel
history) if the model SQL introduced a change in the quantity, order, names, or
types of columns.  This is a deficiency which simplified the implementation of
this materialization.

## Usage

```
{{ config(materialized='snowflake_timetravel_table') }}

-- the rest of your model...
```

## Integration Tests

First, set the following environment variables:

```
export SNOWFLAKE_TEST_ACCOUNT=
export SNOWFLAKE_TEST_USER=
export SNOWFLAKE_TEST_ROLE=
export SNOWFLAKE_TEST_WAREHOUSE=
export SNOWFLAKE_TEST_DATABASE=
export SNOWFLAKE_TEST_SCHEMA=
export SNOWFLAKE_TEST_PRIVATE_KEY_PATH=
export SNOWFLAKE_TEST_PRIVATE_KEY_PASSPHRASE=
```

Then, run integration tests:

```
make test
```
