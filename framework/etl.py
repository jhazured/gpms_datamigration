import logging
import time
from pyspark.sql import SparkSession
from framework.config import Config

class PySparkETL:
    def __init__(self, spark: SparkSession, config: dict, gcp_project: str, gcs_bucket: str):
        self.spark = spark
        self.config = config
        self.gcp_project = gcp_project
        self.gcs_bucket = gcs_bucket
        self.sources = {}
        self.transformed_df = None
        self.logger = logging.getLogger(__name__)

    def extract(self):
        self.logger.info("Starting data extraction...")
        retries = 0
        max_retries = Config.MAX_RETRIES

        while retries <= max_retries:
            try:
                for name, source in self.config['sources'].items():
                    if source['type'] == 'query':
                        df = self.spark.read.format("bigquery") \
                            .option("query", source['query']) \
                            .option("project", self.gcp_project) \
                            .load()
                    elif source['type'] == 'table':
                        df = self.spark.read.format("bigquery") \
                            .option("table", source['query']) \
                            .option("project", self.gcp_project) \
                            .load()
                    else:
                        raise ValueError(f"Unknown source type: {source['type']}")
                    self.sources[name] = df
                    self.logger.info(f"Extracted source: {name}")
                break  # success, exit retry loop
            except Exception as e:
                retries += 1
                self.logger.error(f"Extraction failed on attempt {retries} with error: {e}")
                if retries > max_retries:
                    self.logger.critical("Max retries exceeded during extraction. Aborting job.")
                    raise
                wait_time = min(2 ** retries, Config.TIMEOUT_SECONDS)
                self.logger.info(f"Retrying extraction after {wait_time} seconds...")
                time.sleep(wait_time)

    def transform(self):
        self.logger.info("Starting transformation...")
        for name, df in self.sources.items():
            df.createOrReplaceTempView(name)
            self.logger.debug(f"Registered temp view: {name}")

        sql_query = self.config['query']['sql']
        self.transformed_df = self.spark.sql(sql_query)
        self.logger.info("Transformation complete.")

    def load(self):
        self.logger.info("Starting load process...")
        mapping = self.config.get('mapping', {})
        for src_col, tgt_col in mapping.items():
            self.transformed_df = self.transformed_df.withColumnRenamed(src_col, tgt_col)
            self.logger.debug(f"Renamed column: {src_col} -> {tgt_col}")

        target_table = self.config['query'].get('target_table')
        if target_table and self.gcs_bucket:
            output_path = f"gs://{self.gcs_bucket}/{target_table}/"
            self.transformed_df.write.mode("overwrite").parquet(output_path)
            self.logger.info(f"Data loaded to: {output_path}")
        else:
            self.logger.warning("No target_table or GCS bucket specified; showing DataFrame instead:")
            self.transformed_df.show()

    def run(self):
        self.logger.info("ETL job started.")
        self.extract()
        self.transform()
        self.load()
        self.logger.info("ETL job finished successfully.")
