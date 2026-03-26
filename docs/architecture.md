# GitHub Analytics Data Warehouse - Architecture

## Overview

This data warehouse implements a modern **medallion architecture** (bronze → silver → gold) to transform raw GitHub API data into actionable analytics. The architecture follows dimensional modeling best practices with a star schema design.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                          EXTRACTION LAYER                            │
│                              (dlt)                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  GitHub REST API                                                     │
│  ├── Repositories                                                    │
│  ├── Issues                                                          │
│  ├── Pull Requests                                                   │
│  ├── Comments                                                        │
│  ├── Commits                                                         │
│  ├── Releases                                                        │
│  ├── Stargazers                                                      │
│  └── Contributors                                                    │
│                                                                      │
│  Incremental Loading Strategy:                                       │
│  • Merge: Issues, PRs, Comments, Releases (updated records)         │
│  • Append: Commits, Stargazers (immutable events)                   │
│  • Replace: Repositories, Contributors (full snapshots)             │
│                                                                      │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         BRONZE LAYER                                 │
│                     (DuckDB: raw_github schema)                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Raw tables loaded by dlt:                                           │
│  • repositories                                                      │
│  • issues                                                            │
│  • pull_requests                                                     │
│  • issue_comments                                                    │
│  • commits                                                           │
│  • releases                                                          │
│  • stargazers                                                        │
│  • contributors                                                      │
│                                                                      │
│  Characteristics:                                                    │
│  • Raw JSON structures (flattened by dlt)                           │
│  • Minimal transformation                                            │
│  • Includes dlt metadata (_dlt_load_id, _dlt_id)                   │
│  • Source of truth for all downstream transformations               │
│                                                                      │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         SILVER LAYER                                 │
│                    (dbt: staging + intermediate)                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  STAGING MODELS (1:1 with bronze)                                    │
│  ├── stg_repositories    → Clean, type, rename                      │
│  ├── stg_issues          → Filter out PRs, standardize              │
│  ├── stg_pull_requests   → Calculate is_merged flag                 │
│  ├── stg_issue_comments  → Extract issue numbers                    │
│  ├── stg_commits         → Parse commit metadata                    │
│  ├── stg_releases        → Filter drafts                            │
│  ├── stg_stargazers      → Type timestamps                          │
│  └── stg_users           → Deduplicate across sources, detect bots  │
│                                                                      │
│  INTERMEDIATE MODELS (enrichment & joins)                            │
│  ├── int_issue_lifecycle       → Issue metrics + comment counts     │
│  ├── int_pr_with_reviews       → PR metrics + review data           │
│  └── int_contributor_activity  → Unified activity stream            │
│                                                                      │
│  Characteristics:                                                    │
│  • Cleaned and typed data                                            │
│  • Business logic applied                                            │
│  • Cross-entity joins                                                │
│  • Materialized as views (lightweight)                              │
│                                                                      │
└──────────────────────────┬───────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          GOLD LAYER                                  │
│                      (dbt: marts schema)                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  DIMENSIONAL MODEL (Star Schema)                                     │
│                                                                      │
│  DIMENSIONS                                                          │
│  ├── dim_repositories  → Repository attributes                      │
│  ├── dim_users         → User/contributor profiles                  │
│  └── dim_dates         → Date dimension (2020-2026)                 │
│                                                                      │
│  FACTS                                                               │
│  ├── fct_pull_requests → PR lifecycle & metrics                     │
│  ├── fct_issues        → Issue lifecycle & metrics                  │
│  ├── fct_commits       → Commit activity                            │
│  └── fct_stargazers    → Repository growth events                   │
│                                                                      │
│  METRICS (Aggregated Views)                                          │
│  ├── pr_cycle_time           → Weekly/monthly PR metrics            │
│  ├── contributor_engagement  → Monthly contributor patterns         │
│  └── release_velocity        → Release cadence analysis             │
│                                                                      │
│  Characteristics:                                                    │
│  • Dimensions & facts materialized as tables                        │
│  • Metrics materialized as views                                    │
│  • Surrogate keys for all dimensions                                │
│  • Foreign key relationships enforced via tests                     │
│  • Optimized for analytical queries                                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Extraction (dlt)

**Tool**: dlt (data load tool)  
**Target**: DuckDB local file (`github_dwh.duckdb`)  
**Schema**: `raw_github`

**Process**:
1. Read target repositories from `config/repos.yml`
2. For each repository, extract data from GitHub REST API
3. Apply incremental loading strategies:
   - **Merge**: Update existing records based on `updated_at` (issues, PRs, comments, releases)
   - **Append**: Add new records only (commits, stargazers)
   - **Replace**: Full refresh (repositories, contributors)
4. Handle pagination automatically
5. Respect rate limits (5,000 req/hr with PAT)
6. Load data into bronze tables

**Key Features**:
- Idempotent pipeline (safe to re-run)
- Automatic schema evolution
- Built-in error handling and retries
- State management for incremental loads

### 2. Transformation (dbt)

**Tool**: dbt (data build tool)  
**Source**: `raw_github` schema  
**Target**: `staging`, `intermediate`, `marts` schemas

#### Staging Layer
- **Purpose**: Clean and standardize raw data
- **Materialization**: Views (lightweight, always fresh)
- **Transformations**:
  - Rename columns to snake_case
  - Cast data types (timestamps, booleans)
  - Filter out bots and invalid records
  - Flatten nested structures
  - Add metadata columns

#### Intermediate Layer
- **Purpose**: Enrich and join data across entities
- **Materialization**: Views
- **Transformations**:
  - Calculate lifecycle metrics (time to merge, time to close)
  - Join PRs with reviews and comments
  - Union activity streams
  - Detect patterns (new vs returning contributors)

#### Marts Layer
- **Purpose**: Business-ready dimensional models
- **Materialization**: Tables (for dimensions & facts), Views (for metrics)
- **Transformations**:
  - Build star schema with surrogate keys
  - Create date dimension with date spine
  - Aggregate metrics by time periods
  - Apply business rules

## Star Schema Design

```
                    ┌─────────────────┐
                    │   dim_dates     │
                    ├─────────────────┤
                    │ date_key (PK)   │
                    │ date            │
                    │ year            │
                    │ month           │
                    │ week_of_year    │
                    │ is_weekend      │
                    └─────────────────┘
                            ▲
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
         │                  │                  │
┌────────┴────────┐  ┌──────┴──────────┐  ┌───┴──────────────┐
│ dim_repositories│  │ dim_users       │  │                  │
├─────────────────┤  ├─────────────────┤  │                  │
│ repo_key (PK)   │  │ user_key (PK)   │  │                  │
│ repository_name │  │ user_login      │  │                  │
│ owner_login     │  │ is_bot          │  │                  │
│ language        │  └─────────────────┘  │                  │
│ stars_count     │           ▲            │                  │
└─────────────────┘           │            │                  │
         ▲                    │            │                  │
         │                    │            │                  │
         │         ┌──────────┴────────────┴─────────┐        │
         │         │                                  │        │
         │         │   fct_pull_requests              │        │
         │         ├──────────────────────────────────┤        │
         └─────────┤ pr_key (PK)                      │        │
                   │ repo_key (FK) ───────────────────┘        │
                   │ author_key (FK) ─────────────────────────┘
                   │ created_date_key (FK)
                   │ merged_date_key (FK)
                   │ is_merged
                   │ time_to_merge_hours
                   │ comment_count
                   └──────────────────────────────────┘

Similar patterns for:
- fct_issues
- fct_commits
- fct_stargazers
```

## Data Quality & Testing

### Source Freshness
- Warn after 24 hours
- Error after 72 hours
- Monitored on all bronze tables

### Generic Tests
- `unique`: All primary keys
- `not_null`: All primary and foreign keys
- `relationships`: All foreign keys to dimensions
- `accepted_values`: Enum fields (e.g., period_type)

### Custom Tests
- `assert_no_orphan_prs`: Ensures all PRs have valid repo references
- `assert_positive_cycle_time`: Validates no negative time metrics
- Expression tests: Time metrics must be >= 0

### Test Coverage
- **Bronze layer**: Primary key uniqueness
- **Silver layer**: Data type consistency, bot detection
- **Gold layer**: Referential integrity, business logic validation

## Performance Considerations

### Materialization Strategy
- **Views**: Staging and intermediate (always fresh, no storage overhead)
- **Tables**: Dimensions and facts (pre-computed, fast queries)
- **Incremental**: Not used (small dataset, full refresh is fast)

### DuckDB Optimizations
- Columnar storage (efficient for analytics)
- Automatic compression
- In-memory processing for small datasets
- Single-file database (portable, easy to backup)

### Query Performance
- Surrogate keys for efficient joins
- Date dimension for time-series queries
- Pre-aggregated metrics for dashboards
- Indexed on primary keys automatically

## Scalability Path

### Current State (Portfolio Project)
- Single DuckDB file (~100MB-1GB)
- 1-3 repositories
- Full refresh on each run
- Local development only

### Future Enhancements
1. **More Repositories**: Scale to 10-20 repos
2. **MotherDuck**: Move to cloud DuckDB for remote access
3. **Incremental dbt Models**: Use incremental materialization for facts
4. **Dagster Orchestration**: Replace Makefile with proper orchestration
5. **CI/CD**: Automated testing and deployment
6. **dbt Semantic Layer**: Standardized metric definitions

## Technology Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Extraction | dlt | Incremental data loading from GitHub API |
| Storage | DuckDB | Embedded analytical database |
| Transformation | dbt | SQL-based data transformation |
| Testing | dbt tests | Data quality validation |
| Orchestration | Makefile | Simple pipeline execution |
| Documentation | dbt docs | Auto-generated data catalog |

## Best Practices Demonstrated

1. **Separation of Concerns**: Extract, load, transform as distinct layers
2. **Incremental Loading**: Efficient data updates, not full refreshes
3. **Medallion Architecture**: Progressive data refinement
4. **Dimensional Modeling**: Star schema for analytics
5. **Data Quality**: Comprehensive testing at every layer
6. **Documentation**: Self-documenting code and data catalog
7. **Version Control**: All code in Git
8. **Reproducibility**: Documented setup and configuration

## Monitoring & Observability

### dlt
- Load success/failure logs
- Row counts per table
- API rate limit tracking
- State management for incremental loads

### dbt
- Model run times
- Test pass/fail status
- Source freshness checks
- Data lineage visualization

### DuckDB
- Database size
- Query performance
- Table statistics
