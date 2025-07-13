import os

class Config:
    # Path to Google Cloud credentials JSON file, must be set in env
    GOOGLE_APPLICATION_CREDENTIALS = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

    # Database connection string or project/dataset info for BigQuery
    DB_CONN = os.getenv("DB_CONN")

    # Logging level (default INFO)
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")