# GitHub Analytics Data Warehouse

A modern data platform built with **dlt** (data load tool), **dbt** (data build tool), and **DuckDB**. This project demonstrates end-to-end data engineering best practices:
   - incremental extraction
   - medallion architecture (bronze → silver → gold)
   - dimensional modeling
   - comprehensive testing.
   
For a null cost, we find key aspects of the modern data stack ran entirely locally. The goal was to build a stack an seed-stage company could reuse.

## Architecture

```
GitHub API → dlt (Extract) → DuckDB (Bronze) → dbt (Transform) → Analytics (Silver/Gold)
```

### Medallion Architecture

- **Bronze Layer** (`raw_github` schema): Raw data from GitHub API, loaded incrementally by dlt
- **Silver Layer** (`staging` + `intermediate` models): Cleaned, typed, and enriched data
- **Gold Layer** (`marts` models): Dimensional models (star schema) and business metrics

## Data Sources

Extracting from GitHub REST API:
- Repositories
- Issues & Pull Requests
- PR Reviews
- Comments
- Commits
- Releases
- Stargazers
- Contributors

## Quick Start

### Prerequisites

- Python 3.8+
- GitHub Personal Access Token ([create one here](https://github.com/settings/tokens))
  - Required scope: `public_repo` (read-only)

### Setup

1. **Clone and navigate to the project**
   ```bash
   cd dwh-on-budget
   ```

2. **Create virtual environment and install dependencies**
   ```bash
   make setup
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   make install
   ```

3. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env and add your DuckDB address
   ```

4. **Configure dlt secrets**
   ```bash
   # Create dlt secrets file
   mkdir -p extract/.dlt
   cat > extract/.dlt/secrets.toml << EOF
   [sources.github]
   github_token = "ghp_your_token_here"
   EOF
   ```

5. **Configure target repositories**
   Edit `extract/config/repos.yml` to specify which repos to analyze.

### Run the Pipeline

```bash
# Run full pipeline (extract + transform + test)
make run

# Or run steps individually
make extract    # Extract data from GitHub
make transform  # Run dbt transformations
make test       # Run dbt tests
make docs       # Generate and serve documentation
```

## Project Structure

```
.
├── extract/                      # dlt extraction layer
│   ├── github_pipeline.py        # Main pipeline orchestrator
│   ├── sources/
│   │   └── github.py             # GitHub API source definitions
│   ├── .dlt/
│        ├── config.toml          # dlt configuration
│        └── secrets.toml         # GitHub token (gitignored)
│   └── config/
│       └── repos.yml             # Target repositories
│
├── transform/                    # dbt transformation layer
│   ├── models/
│   │   ├── staging/              # Bronze → Silver (cleaning, typing)
│   │   ├── intermediate/         # Silver (joins, enrichment)
│   │   └── marts/                # Gold (dimensions, facts, metrics)
│   ├── macros/                   # Reusable SQL functions
│   ├── tests/                    # Custom data tests
│   └── dbt_project.yml
│
├── analysis/                     # Ad-hoc queries and exploration
├── docs/                         # Documentation
└── Makefile                      # Pipeline orchestration
```

## Key Features

### Extraction (dlt)
- Incremental loading with replace/merge/append strategies
- Automatic pagination handling
- Rate limit management
- Idempotent pipeline runs

### Transformation (dbt)
- Staging models with data cleaning and typing
- Intermediate models for cross-entity joins
- Star schema with dimensions and facts
- Business metric calculations
- Comprehensive testing (generic + custom)
- Source freshness monitoring
- Full documentation with data catalog

### Data Models

#### Dimensions
- `dim_repositories`: Repository attributes and metadata
- `dim_users`: User/contributor profiles
- `dim_dates`: Date dimension for time-series analysis

#### Facts
- `fct_pull_requests`: PR lifecycle and metrics
- `fct_issues`: Issue tracking and resolution
- `fct_commits`: Commit activity
- `fct_stargazers`: Repository growth over time

#### Metrics
- `pr_cycle_time`: Time-to-merge analysis
- `contributor_engagement`: Contributor activity patterns
- `release_velocity`: Release cadence and health

## Testing

The project includes comprehensive data quality tests:

- **Generic tests**: `unique`, `not_null`, `relationships` on all keys
- **Custom tests**: Business logic validation (e.g., no negative cycle times)
- **Source freshness**: Alerts on stale data

Run tests with:
```bash
make test
```

## Documentation

Generate and browse the full data catalog:
```bash
make docs
```

This will start a local web server with:
- Data lineage graphs
- Column-level documentation
- Test coverage
- Model relationships

## Maintenance

```bash
# Clean generated files and database
make clean

# Full reset (including virtual environment)
make reset
```

## Future Enhancements

- [ ] Dagster orchestration for production scheduling
- [ ] MotherDuck integration for cloud analytics
- [ ] CI/CD pipeline with GitHub Actions
- [ ] dbt Semantic Layer for standardized metrics
- [ ] Multi-repo comparison dashboards
- [ ] Jupyter notebooks for exploratory analysis

## Contributing

This is a portfolio project, but suggestions and feedback are welcome!

---

**Built with ❤️ using dlt, dbt, and DuckDB**
