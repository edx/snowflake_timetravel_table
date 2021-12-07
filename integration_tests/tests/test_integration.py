import os
import subprocess
import json
import pathlib
import pytest

TEST_FILE_PATH = pathlib.Path(__file__).parent.absolute()
COMPILED_SQL_DIR = os.path.join(
    TEST_FILE_PATH,
    "../run_project/target/run/snowflake_timetravel_table_integration_tests/models",
)
RUN_RESULTS_PATH = os.path.join(
    TEST_FILE_PATH,
    "../run_project/target/run_results.json",
)


@pytest.mark.parametrize(
    "test_model,snippets",
    [
        (
            "snowflake_timetravel_table_integration_tests_table_does_not_exist",
            ("create or replace  table",),
        ),
        (
            "snowflake_timetravel_table_integration_tests_was_a_view",
            ("create or replace  table",),
        ),
        (
            "snowflake_timetravel_table_integration_tests_columns_no_change",
            (
                "truncate table",
                "insert into",
            ),
        ),
        (
            "snowflake_timetravel_table_integration_tests_columns_added",
            ("create or replace  table",),
        ),
        (
            "snowflake_timetravel_table_integration_tests_columns_removed",
            ("create or replace  table",),
        ),
        (
            "snowflake_timetravel_table_integration_tests_columns_renamed",
            ("create or replace  table",),
        ),
        (
            "snowflake_timetravel_table_integration_tests_column_types_changed",
            ("create or replace  table",),
        ),
    ],
)
def test_snippets_in_compiled_sql(test_model, snippets):
    """
    Search the compiled SQL for each test model to ensure they contain specific SQL statement snippets.

    Args:
        test_model (str): The name of the dbt model to test.
        snippets (list of str): the lowercase SQL snippets to attempt to find in the compiled SQL.
    """
    test_model_filename = "{}.sql".format(test_model)
    compiled_model_path = os.path.join(COMPILED_SQL_DIR, test_model_filename)
    with open(compiled_model_path, "r") as compiled_model_file:
        compiled_sql = compiled_model_file.read().lower()
    for snippet in snippets:
        assert snippet in compiled_sql


def test_validate_time_travel():
    """
    Actually run the SQL which uses time travel to validate that it actually works with the truncate+insert method.
    """
    with open(RUN_RESULTS_PATH, "r") as run_results_file:
        run_results = json.load(run_results_file)

    no_change_model_results = None
    for model_results in run_results["results"]:
        if model_results["unique_id"].endswith(".snowflake_timetravel_table_integration_tests_columns_no_change"):
            no_change_model_results = model_results
            break

    # Determine when exactly the _columns_no_change test started to execute which is close to the moment when time
    # travel history changes for this model.
    execute_timings = [timing for timing in no_change_model_results["timing"] if timing["name"] == "execute"][0]
    no_change_test_start_time = execute_timings["started_at"]

    # Invoke `dbt test` to run the test which actually uses time travel and validates that the results are historical
    # rows from the table.
    my_env = os.environ.copy()
    my_env["TIMESTAMP_BEFORE_TRUNCATE_INSERT"] = no_change_test_start_time
    completed_process = subprocess.run(
        [
            "dbt",
            "test",
            "-m",
            "test_snowflake_timetravel_table_integration_tests_columns_no_change",
            "--project-dir",
            os.path.join(TEST_FILE_PATH, "../run_project"),
            "--profiles-dir",
            os.path.join(TEST_FILE_PATH, "../test_profile"),
        ],
        env=my_env,
    )
    assert completed_process.returncode == 0
