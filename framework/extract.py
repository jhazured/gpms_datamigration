from pyspark.sql import SparkSession

def extract(spark: SparkSession, sources: dict, gcp_project: str) -> dict:
    """
    Extract DataFrames from BigQuery sources.
    """
    dfs = {}

    for name, source in sources.items():
        source_type = source.get('type')
        if source_type == 'query':
            df = (
                spark.read.format("bigquery")
                .option("query", source['query'])
                .option("project", gcp_project)
                .load()
            )
        elif source_type == 'table':
            df = (
                spark.read.format("bigquery")
                .option("table", source['table'])
                .option("project", gcp_project)
                .load()
            )
        else:
            raise ValueError(f"Unknown source type: {source_type} for source {name}")

        dfs[name] = df
        print(f" Extracted source: {name}")
    return dfs

