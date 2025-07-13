import pytest
from unittest.mock import MagicMock, patch
from pyspark.sql import SparkSession
from framework.etl import PySparkETL

@pytest.fixture
def mock_spark():
    spark = MagicMock()
    reader = MagicMock()
    reader.option.return_value = reader
    reader.load.return_value = MagicMock()
    spark.read.format.return_value = reader
    return spark

@pytest.fixture
def sample_config():
    return {
        "sources": {
            "customers": {
                "type": "query",
                "query": "SELECT * FROM customers"
            },
            "orders": {
                "type": "table",
                "query": "orders_table"
            }
        },
        "query": {
            "sql": "SELECT * FROM customers JOIN orders ON customers.customer_id = orders.customer_id",
            "target_table": "output_table"
        },
        "mapping": {
            "old_col": "new_col"
        }
    }

@patch("framework.etl.logging")
def test_run_success(mock_logging, mock_spark, sample_config):
    etl = PySparkETL(mock_spark, sample_config, "my_project", "my_bucket")
    etl.transform = MagicMock()
    etl.load = MagicMock()

    etl.run()

    assert "customers" in etl.sources
    assert "orders" in etl.sources
    etl.transform.assert_called_once()
    etl.load.assert_called_once()
    assert mock_logging.getLogger.return_value.info.call_count >= 2

@patch("framework.etl.time.sleep", return_value=None)
@patch("framework.etl.logging")
def test_extract_retry_failure(mock_logging, mock_sleep, mock_spark, sample_config):
    etl = PySparkETL(mock_spark, sample_config, "my_project", "my_bucket")

    def fail_load(*args, **kwargs):
        raise Exception("Load failed")

    reader = MagicMock()
    reader.option.return_value = reader
    reader.load.side_effect = fail_load
    mock_spark.read.format.return_value = reader

    with pytest.raises(Exception) as excinfo:
        etl.extract()

    assert "Load failed" in str(excinfo.value)
    assert mock_logging.getLogger.return_value.error.call_count >= 1
    assert mock_logging.getLogger.return_value.critical.call_count == 1

def test_transform_registers_views_and_runs_sql(mock_spark, sample_config):
    etl = PySparkETL(mock_spark, sample_config, "my_project", "my_bucket")
    df_mock = MagicMock()
    etl.sources = {'customers': df_mock, 'orders': df_mock}
    df_mock.createOrReplaceTempView = MagicMock()
    mock_spark.sql = MagicMock(return_value="transformed_df")

    etl.transform()

    df_mock.createOrReplaceTempView.assert_any_call('customers')
    df_mock.createOrReplaceTempView.assert_any_call('orders')
    mock_spark.sql.assert_called_once_with(sample_config['query']['sql'])
    assert etl.transformed_df == "transformed_df"

def test_load_writes_to_gcs_and_renames_columns():
    etl = PySparkETL(None, {
        'query': {'target_table': 'my_table'},
        'mapping': {'old_col': 'new_col'}
    }, "my_project", "my_bucket")

    df_mock = MagicMock()
    df_mock.withColumnRenamed.return_value = df_mock
    df_mock.write.mode.return_value.parquet = MagicMock()
    etl.transformed_df = df_mock

    etl.load()

    df_mock.withColumnRenamed.assert_called_with('old_col', 'new_col')
    df_mock.write.mode.return_value.parquet.assert_called_with("gs://my_bucket/my_table/")

def test_load_shows_when_no_target_table_or_bucket():
    etl = PySparkETL(None, {
        'query': {},
        'mapping': {}
    }, "my_project", None)

    df_mock = MagicMock()
    etl.transformed_df = df_mock

    etl.load()

    df_mock.show.assert_called_once()

def test_etl_run_integration(sample_config):
    spark = SparkSession.builder \
        .master("local[1]") \
        .appName("test_etl_integration") \
        .getOrCreate()

    etl = PySparkETL(spark, sample_config, "dummy_project", None)

    etl.extract = lambda: None
    etl.sources = {
        'customers': spark.createDataFrame(
            [(1, 'Alice'), (2, 'Bob')],
            ['customer_id', 'customer_name']
        ),
        'orders': spark.createDataFrame(
            [(1, 1, 100), (2, 2, 150)],
            ['order_id', 'customer_id', 'order_amount']
        )
    }

    etl.transform()

    assert etl.transformed_df is not None
    assert 'customer_id' in etl.transformed_df.columns

    spark.stop()
