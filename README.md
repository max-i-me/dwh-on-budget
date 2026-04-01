# GitHub Analytics Data Warehouse

A modern data platform using **dlt**, **dbt**, and **DuckDB**. Demonstrates end-to-end data engineering with incremental extraction, medallion architecture, and dimensional modeling - all running locally at zero cost.

Built for seed-stage startups that need analytics without the enterprise price tag.

## Architecture

```
GitHub API → dlt → DuckDB (Bronze) → dbt → Analytics (Silver/Gold)
```

### Automated Daily Refresh

The pipeline runs automatically every day at 2 AM UTC via GitHub Actions:
- Extracts new data from GitHub API (incremental)
- Transforms with dbt (staging → marts)
- Runs data quality tests
- Stores database as artifact for next run
- Sends Slack notifications on success/failure

Manual runs available via GitHub Actions UI.

### Medallion Layers

- **Bronze** (`raw_github`): Raw API data, incrementally loaded
- **Silver** (staging models): Cleaned and typed
- **Gold** (marts): Star schema with dimensions and facts

## Data Sources

GitHub REST API:
- Repositories, Issues, Pull Requests
- Reviews, Comments, Commits
- Releases, Stargazers, Contributors

## Quick Start

### Prerequisites

- Python 3.8+
- GitHub Personal Access Token with `public_repo` scope ([create one](https://github.com/settings/tokens))

### Setup

1. Clone and install:
   ```bash
   make setup
   source .venv/bin/activate
   make install
   ```

2. Configure environment:
   ```bash
   cp .env.example .env
   # Edit .env with your DuckDB path
   ```

3. Add GitHub token:
   ```bash
   mkdir -p extract/.dlt
   cat > extract/.dlt/secrets.toml << EOF
   [sources.github]
   github_token = "ghp_your_token_here"
   EOF
   ```

4. Configure repos in `extract/config/repos.yml`

### Run

```bash
make run          # Full pipeline
make extract      # Just extraction
make transform    # Just dbt
make test         # Run tests
make docs         # Generate docs
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

- **Incremental loading** with automatic pagination and rate limiting
- **Star schema** with dimensions and facts
- **Comprehensive testing** (generic + custom data quality tests)
- **Full documentation** with lineage graphs
- **Automated daily refresh** via GitHub Actions

## Data Models

**Dimensions:**
- `dim_repositories` - Repository metadata
- `dim_users` - User profiles
- `dim_dates` - Date dimension

**Facts:**
- `fct_pull_requests` - PR lifecycle metrics
- `fct_issues` - Issue tracking
- `fct_commits` - Commit activity
- `fct_stargazers` - Repository growth

**Metrics:**
- PR cycle time analysis
- Contributor engagement
- Release velocity

## Testing

Comprehensive data quality tests:
- Generic tests (unique, not_null, relationships)
- Custom business logic validation
- Source freshness checks

```bash
make test
```

## Documentation

```bash
make docs  # Starts local server with lineage graphs and data catalog
```

## Maintenance

```bash
make clean   # Clean generated files
make reset   # Full reset
```

## Roadmap

- [x] GitHub Actions automation
- [x] Multi-repository support
- [ ] Metabase dashboards
- [ ] MotherDuck integration
- [ ] dbt Semantic Layer

## Contributing

Portfolio project - feedback welcome!

---

*Modern data stack for seed-stage startups*
