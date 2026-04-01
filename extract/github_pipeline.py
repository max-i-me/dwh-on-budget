"""
Main dlt pipeline for GitHub Analytics Data Warehouse.

This script orchestrates the extraction of GitHub data using dlt,
loading it into DuckDB for downstream transformation by dbt.
"""

import dlt
import yaml
import os
from pathlib import Path
from dotenv import load_dotenv
from sources.github import github_source

# Load environment variables from project root
project_root = Path(__file__).parent.parent
load_dotenv(project_root / ".env")

# Configuration
DUCKDB_PATH = os.getenv("DUCKDB_PATH", "../data/dwhonbudget.duckdb")
# Resolve to absolute path relative to project root
if not os.path.isabs(DUCKDB_PATH):
    DUCKDB_PATH = str(project_root / DUCKDB_PATH)

REPOS_CONFIG = Path(__file__).parent / "config" / "repos.yml"


def load_repos_config() -> list:
    """Load target repositories from config file."""
    if not REPOS_CONFIG.exists():
        raise FileNotFoundError(
            f"Repository config not found: {REPOS_CONFIG}\n"
            "Please create config/repos.yml with target repositories."
        )
    
    with open(REPOS_CONFIG, "r") as f:
        config = yaml.safe_load(f)
    
    return config.get("repositories", [])


def run_pipeline():
    """Execute the GitHub data extraction pipeline."""
    
    print("Starting GitHub Analytics extraction pipeline...")
    
    # Load target repositories
    repos = load_repos_config()
    
    if not repos:
        raise ValueError("No repositories configured in repos.yml")
    
    print(f"📊 Configured to extract data from {len(repos)} repository(ies):")
    for repo in repos:
        print(f"   - {repo['owner']}/{repo['name']}")
    
    # Configure dlt pipeline
    pipeline = dlt.pipeline(
        pipeline_name="github_analytics",
        destination=dlt.destinations.duckdb(DUCKDB_PATH),
        dataset_name="raw_github",
        progress="log",
    )
    
    # Extract data from each repository
    for repo_config in repos:
        owner = repo_config["owner"]
        name = repo_config["name"]
        initial_date = repo_config["initial_date"]
        
        print(f"\n Extracting data from {owner}/{name}...")
        print(f"   Initial extraction date: {initial_date}")
        try:
            # Get GitHub token from dlt secrets
            # This will look for: extract/.dlt/secrets.toml
            source = github_source(
                owner=owner,
                repo=name,
            )
            
            # Run the pipeline
            load_info = pipeline.run(
                source,
                write_disposition="merge",
            )
            
            print(f"Successfully loaded data from {owner}/{name}")
            print(f"Loaded {len(load_info.loads_ids)} load package(s)")
            
        except Exception as e:
            print(f"Error extracting data from {owner}/{name}: {str(e)}")
            raise
    
    # Print pipeline statistics
    print("\n" + "="*60)
    print("📈 Pipeline Summary")
    print("="*60)
    
    # Get row counts for each table
    with pipeline.sql_client() as client:
        tables = [
            "repositories",
            "issues",
            #"pull_requests",
            "issue_comments",
            "commits",
            "releases",
            "stargazers",
            "contributors",
        ]
        
        for table in tables:
            try:
                result = client.execute_sql(
                    f"SELECT COUNT(*) as count FROM raw_github.{table}"
                )
                count = result[0][0]
                print(f"   {table:20s}: {count:>8,} rows")
            except Exception:
                print(f"   {table:20s}: (not found)")
    
    print("="*60)
    print("Pipeline completed successfully!")
    print(f"Data stored in: {DUCKDB_PATH}")
    print("\nNext steps:")
    print("  1. Run 'make transform' to transform data with dbt")
    print("  2. Run 'make test' to validate data quality")
    print("  3. Run 'make docs' to view documentation")


if __name__ == "__main__":
    run_pipeline()
