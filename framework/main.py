import sys
from pyspark.sql import SparkSession
from framework.config import load_job_config, get_gcp_project, get_gcs_bucket
from framework.etl import PySparkETL

def main(job_yaml_path: str):
    spark = SparkSession.builder.appName("ETLJobRunner") \
        .config("spark.jars.packages", "com.google.cloud.spark:spark-bigquery-with-dependencies_2.12:0.30.0") \
        .getOrCreate()

    config = load_job_config(job_yaml_path)
    gcp_project = get_gcp_project()
    gcs_bucket = get_gcs_bucket()

    job = PySparkETL(spark, config, gcp_project, gcs_bucket)
    job.run()

    spark.stop()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python main.py <job_yaml_path>")
        sys.exit(1)
    main(sys.argv[1])

