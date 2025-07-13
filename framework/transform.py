from pyspark.sql import SparkSession

def transform(spark: SparkSession, dfs: dict, query_sql: str):
    """
    Register DataFrames as temp views and run the SQL.
    """
    for name, df in dfs.items():
        df.createOrReplaceTempView(name)
        print(f" Registered temp view: {name}")

    result_df = spark.sql(query_sql)
    print(" Transformation complete.")
    return result_df