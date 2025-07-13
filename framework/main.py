import sys
import logging
from pyspark.sql import SparkSession
from framework.config import Config, load_job_config, get_gcp_project, get_gcs_bucket
from framework.etl import PySparkETL

def setup_logging():
    level = getattr(logging, Config.LOG_LEVEL.upper(), logging.INFO)
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )

def main(job_yaml_path: str):
    Config.validate()  # Ensure mandatory env vars are set
    setup_logging()
    logging.info(f"Starting ETL job with config: {job_yaml_path}")

    spark = SparkSession.builder.appName(Config.APP_NAME) \
        .config("spark.jars.packages", "com.google.cloud.spark:spark-bigquery-with-dependencies_2.12:0.30.0") \
        .getOrCreate()

    config = load_job_config(job_yaml_path)
    gcp_project = get_gcp_project() or Config.GCP_PROJECT
    gcs_bucket = get_gcs_bucket() or Config.GCS_BUCKET

    job = PySparkETL(spark, config, gcp_project, gcs_bucket)
    job.run()

    spark.stop()
    logging.info("ETL job completed successfully")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python main.py <job_yaml_path>")
        sys.exit(1)
    main(sys.argv[1])
