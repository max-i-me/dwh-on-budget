"""
GitHub data extraction pipeline using dlt.
Loads data from GitHub API into DuckDB.
"""

import dlt
import yaml
import os
from pathlib import Path
from dotenv import load_dotenv
from sources.github import github_source

project_root = Path(__file__).parent.parent
load_dotenv(project_root / ".env")

DUCKDB_PATH = os.getenv("DUCKDB_PATH", "../data/dwhonbudget.duckdb")
if not os.path.isabs(DUCKDB_PATH):
    DUCKDB_PATH = str(project_root / DUCKDB_PATH)

REPOS_CONFIG = Path(__file__).parent / "config" / "repos.yml"

def load_repos_config() -> list:
    if not REPOS_CONFIG.exists():
        raise FileNotFoundError(f"Config not found: {REPOS_CONFIG}")
    
    with open(REPOS_CONFIG, "r") as f:
        config = yaml.safe_load(f)
    
    return config.get("repositories", [])


def run_pipeline():
    print("Starting GitHub extraction...")
    
    repos = load_repos_config()
    if not repos:
        raise ValueError("No repositories configured")
    
    print(f"Extracting from {len(repos)} repo(s):")
    for repo in repos:
        print(f"  - {repo['owner']}/{repo['name']}")
    
    pipeline = dlt.pipeline(
        pipeline_name="github_analytics",
        destination=dlt.destinations.duckdb(DUCKDB_PATH),
        dataset_name="raw_github",
        progress="log",
    )
    
    for repo_config in repos:
        owner = repo_config["owner"]
        name = repo_config["name"]
        initial_date = repo_config["initial_date"]
        
        print(f"\nExtracting {owner}/{name} (from {initial_date})...")
        try:
            source = github_source(owner=owner, repo=name)
            
            load_info = pipeline.run(source, write_disposition="merge")
            
            print(f"Loaded {owner}/{name}")
            
        except Exception as e:
            print(f"Error extracting {owner}/{name}: {e}")
            raise
    
    print("\n" + "="*50)
    print("Pipeline Summary")
    print("="*50)
    
    with pipeline.sql_client() as client:
        tables = ["repositories", "issues", "issue_comments", 
                  "commits", "releases", "stargazers", "contributors"]
        
        for table in tables:
            try:
                result = client.execute_sql(
                    f"SELECT COUNT(*) as count FROM raw_github.{table}"
                )
                count = result[0][0]
                print(f"  {table:20s}: {count:>8,} rows")
            except Exception:
                pass
    
    print("="*50)
    print(f"\nDone. Data in: {DUCKDB_PATH}")


if __name__ == "__main__":
    run_pipeline()
