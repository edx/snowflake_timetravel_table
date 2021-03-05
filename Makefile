
# Perform integration tests.
#
# For this to work, you must have the following environment variables set:
#
# export SNOWFLAKE_TEST_ACCOUNT=
# export SNOWFLAKE_TEST_USER=
# export SNOWFLAKE_TEST_ROLE=
# export SNOWFLAKE_TEST_WAREHOUSE=
# export SNOWFLAKE_TEST_DATABASE=
# export SNOWFLAKE_TEST_SCHEMA=
# export SNOWFLAKE_TEST_PRIVATE_KEY_PATH=
# export SNOWFLAKE_TEST_PRIVATE_KEY_PASSPHRASE=
#
test:
	tox

check-black:
	tox -e black

black:
	black --line-length 120 integration_tests/tests
