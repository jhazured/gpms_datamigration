import yaml

def load_job_config(filepath: str) -> dict:
    with open(filepath, 'r') as f:
        job_config = yaml.safe_load(f)
    return job_config
