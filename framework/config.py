import os
import yaml
from dotenv import load_dotenv

# Load environment variables from a .env file in the project root (if present)
load_dotenv()

class Config:
    """
    Configuration class for environment variables.
    Reads from OS environment or .env file.
    """

    # Application settings
    APP_NAME = os.getenv("APP_NAME", "gcp_datamigration_etl")
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

    # Database connection details
    DB_HOST = os.getenv("DB_HOST", "localhost")
    DB_PORT = int(os.getenv("DB_PORT", 5432))
    DB_USER = os.getenv("DB_USER", "")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "")
    DB_NAME = os.getenv("DB_NAME", "")

    # Google Cloud settings
    GOOGLE_APPLICATION_CREDENTIALS = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")
    GCP_PROJECT = os.getenv("GCP_PROJECT", "")
    GCS_BUCKET = os.getenv("GCS_BUCKET", "")

    # Operational settings
    MAX_RETRIES = int(os.getenv("MAX_RETRIES", 3))
    TIMEOUT_SECONDS = int(os.getenv("TIMEOUT_SECONDS", 60))

    @staticmethod
    def validate():
        """
        Optional: Validate critical config variables are set.
        Raises exception if mandatory vars are missing.
        """
        missing = []
        if not Config.DB_USER:
            missing.append("DB_USER")
        if not Config.DB_PASSWORD:
            missing.append("DB_PASSWORD")
        if not Config.DB_NAME:
            missing.append("DB_NAME")
        if not Config.GCP_PROJECT:
            missing.append("GCP_PROJECT")
        if missing:
            raise EnvironmentError(f"Missing mandatory environment variables: {', '.join(missing)}")


def load_job_config(job_yaml_path: str) -> dict:
    """
    Load and parse the YAML ETL job configuration from the given file path.
    """
    if not os.path.exists(job_yaml_path):
        raise FileNotFoundError(f"ETL job config file not found: {job_yaml_path}")

    with open(job_yaml_path, 'r') as f:
        config = yaml.safe_load(f)

    return config


def get_gcp_project() -> str:
    """
    Return the GCP project name from environment or None if not set.
    """
    return os.getenv("GCP_PROJECT")


def get_gcs_bucket() -> str:
    """
    Return the GCS bucket name from environment or None if not set.
    """
    return os.getenv("GCS_BUCKET")
