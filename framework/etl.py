from pyspark.sql import SparkSession

class PySparkETL:
    def __init__(self, spark: SparkSession, config: dict, gcp_project: str, gcs_bucket: str):
        self.spark = spark
        self.config = config
        self.gcp_project = gcp_project
        self.gcs_bucket = gcs_bucket
        self.sources = {}
        self.transformed_df = None

    def extract(self):
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
            print(f" Extracted source: {name}")

    def transform(self):
        for name, df in self.sources.items():
            df.createOrReplaceTempView(name)
            print(f" Registered temp view: {name}")

        sql_query = self.config['query']['sql']
        self.transformed_df = self.spark.sql(sql_query)
        print(" Transformation complete.")

    def load(self):
        mapping = self.config.get('mapping', {})
        for src_col, tgt_col in mapping.items():
            self.transformed_df = self.transformed_df.withColumnRenamed(src_col, tgt_col)
            print(f"Renamed: {src_col} -> {tgt_col}")

        target_table = self.config['query'].get('target_table')
        if target_table and self.gcs_bucket:
            output_path = f"gs://{self.gcs_bucket}/{target_table}/"
            self.transformed_df.write.mode("overwrite").parquet(output_path)
            print(f" Loaded to: {output_path}")
        else:
            print(" No target_table or GCS bucket; showing DataFrame:")
            self.transformed_df.show()

    def run(self):
        self.extract()
        self.transform()
        self.load()

