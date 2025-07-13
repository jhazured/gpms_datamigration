from pyspark.sql import DataFrame

def load(df, mapping: dict, target_table: str, gcs_bucket: str):
    """
    Rename columns using mapping and write to GCS bucket.
    """
    for src_col, tgt_col in mapping.items():
        df = df.withColumnRenamed(src_col, tgt_col)
        print(f"Renamed: {src_col} -> {tgt_col}")

    if target_table and gcs_bucket:
        output_path = f"gs://{gcs_bucket}/{target_table}/"
        df.write.mode("overwrite").parquet(output_path)
        print(f" Data written to: {output_path}")
    else:
        print(" No target_table or GCS bucket specified; displaying DataFrame:")
        df.show()
