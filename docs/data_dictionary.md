# Data Dictionary

## Overview

This document provides detailed descriptions of all tables, columns, and relationships in the GitHub Analytics Data Warehouse.

---

## Table of Contents

1. [Bronze Layer (raw_github)](#bronze-layer)
2. [Silver Layer (staging)](#silver-layer-staging)
3. [Silver Layer (intermediate)](#silver-layer-intermediate)
4. [Gold Layer (marts - Dimensions)](#gold-layer-dimensions)
5. [Gold Layer (marts - Facts)](#gold-layer-facts)
6. [Gold Layer (marts - Metrics)](#gold-layer-metrics)

---

## Bronze Layer

### raw_github.repositories
Raw repository metadata from GitHub API.

| Column | Type | Description |
|--------|------|-------------|
| id | BIGINT | GitHub repository ID (PK) |
| owner_login | TEXT | Repository owner username |
| repo_name | TEXT | Repository name |
| full_name | TEXT | Full repository name (owner/repo) |
| description | TEXT | Repository description |
| private | BOOLEAN | Whether repository is private |
| created_at | TIMESTAMP | Repository creation timestamp |
| stargazers_count | INTEGER | Number of stars |
| forks_count | INTEGER | Number of forks |
| language | TEXT | Primary programming language |

### raw_github.issues
Issues (excluding pull requests) from GitHub API.

| Column | Type | Description |
|--------|------|-------------|
| id | BIGINT | GitHub issue ID (PK) |
| number | INTEGER | Issue number within repository |
| title | TEXT | Issue title |
| state | TEXT | Issue state (open/closed) |
| user_login | TEXT | Author username |
| user_id | BIGINT | Author user ID |
| created_at | TIMESTAMP | Issue creation timestamp |
| updated_at | TIMESTAMP | Last update timestamp |
| closed_at | TIMESTAMP | Closure timestamp (nullable) |

### raw_github.pull_requests
Pull requests from GitHub API.

| Column | Type | Description |
|--------|------|-------------|
| id | BIGINT | GitHub PR ID (PK) |
| number | INTEGER | PR number within repository |
| title | TEXT | PR title |
| state | TEXT | PR state (open/closed) |
| user_login | TEXT | Author username |
| user_id | BIGINT | Author user ID |
| merged_at | TIMESTAMP | Merge timestamp (nullable) |
| created_at | TIMESTAMP | PR creation timestamp |
| updated_at | TIMESTAMP | Last update timestamp |

### raw_github.issue_comments
Comments on issues and pull requests.

| Column | Type | Description |
|--------|------|-------------|
| id | BIGINT | GitHub comment ID (PK) |
| issue_number | INTEGER | Associated issue/PR number |
| user_login | TEXT | Comment author username |
| user_id | BIGINT | Comment author user ID |
| body | TEXT | Comment content |
| created_at | TIMESTAMP | Comment creation timestamp |
| updated_at | TIMESTAMP | Last update timestamp |

### raw_github.commits
Repository commits.

| Column | Type | Description |
|--------|------|-------------|
| sha | TEXT | Git commit SHA (PK) |
| author_login | TEXT | GitHub author username (nullable) |
| author_id | BIGINT | GitHub author user ID (nullable) |
| commit_author_name | TEXT | Git commit author name |
| commit_author_email | TEXT | Git commit author email |
| commit_date | TIMESTAMP | Commit timestamp |
| message | TEXT | Commit message |

### raw_github.releases
Repository releases.

| Column | Type | Description |
|--------|------|-------------|
| id | BIGINT | GitHub release ID (PK) |
| tag_name | TEXT | Release tag name |
| name | TEXT | Release name |
| draft | BOOLEAN | Whether release is a draft |
| prerelease | BOOLEAN | Whether release is a prerelease |
| published_at | TIMESTAMP | Publication timestamp |
| created_at | TIMESTAMP | Creation timestamp |

### raw_github.stargazers
Users who starred repositories (with timestamps).

| Column | Type | Description |
|--------|------|-------------|
| user_id | BIGINT | User who starred |
| user_login | TEXT | Username |
| starred_at | TIMESTAMP | When star was added |
| repository_full_name | TEXT | Repository that was starred |

### raw_github.contributors
Repository contributors.

| Column | Type | Description |
|--------|------|-------------|
| user_id | BIGINT | Contributor user ID |
| user_login | TEXT | Contributor username |
| contributions | INTEGER | Number of contributions |
| repository_full_name | TEXT | Repository contributed to |

---

## Silver Layer (Staging)

### staging.stg_repositories
Cleaned repository data.

| Column | Type | Description | Transformation |
|--------|------|-------------|----------------|
| repository_id | BIGINT | Repository ID (PK) | Renamed from id |
| repository_name | TEXT | Repository name | Renamed from repo_name |
| repository_full_name | TEXT | Full name (owner/repo) | Renamed from full_name |
| owner_login | TEXT | Owner username | - |
| primary_language | TEXT | Primary language | Renamed from language |
| stargazers_count | INTEGER | Star count | - |
| is_private | BOOLEAN | Private flag | Renamed from private |
| is_archived | BOOLEAN | Archived flag | Renamed from archived |
| created_at | TIMESTAMP | Creation timestamp | Cast to timestamp |

### staging.stg_issues
Cleaned issue data (PRs excluded).

| Column | Type | Description | Transformation |
|--------|------|-------------|----------------|
| issue_id | BIGINT | Issue ID (PK) | Renamed from id |
| issue_number | INTEGER | Issue number | Renamed from number |
| issue_title | TEXT | Issue title | Renamed from title |
| issue_state | TEXT | State (open/closed) | Renamed from state |
| author_login | TEXT | Author username | Renamed from user_login |
| author_id | BIGINT | Author user ID | Renamed from user_id |
| label_list | ARRAY | Issue labels | - |
| comments_count | INTEGER | Comment count | - |
| is_locked | BOOLEAN | Locked flag | Renamed from locked |
| created_at | TIMESTAMP | Creation timestamp | Cast to timestamp |
| closed_at | TIMESTAMP | Closure timestamp | Cast to timestamp |

### staging.stg_pull_requests
Cleaned pull request data.

| Column | Type | Description | Transformation |
|--------|------|-------------|----------------|
| pull_request_id | BIGINT | PR ID (PK) | Renamed from id |
| pr_number | INTEGER | PR number | Renamed from number |
| pr_title | TEXT | PR title | Renamed from title |
| pr_state | TEXT | State (open/closed) | Renamed from state |
| author_login | TEXT | Author username | Renamed from user_login |
| author_id | BIGINT | Author user ID | Renamed from user_id |
| is_merged | BOOLEAN | Merged flag | Calculated from merged_at |
| is_draft | BOOLEAN | Draft flag | Renamed from draft |
| label_list | ARRAY | PR labels | - |
| created_at | TIMESTAMP | Creation timestamp | Cast to timestamp |
| merged_at | TIMESTAMP | Merge timestamp | Cast to timestamp |

### staging.stg_issue_comments
Cleaned comment data.

| Column | Type | Description | Transformation |
|--------|------|-------------|----------------|
| comment_id | BIGINT | Comment ID (PK) | Renamed from id |
| issue_number | INTEGER | Associated issue/PR | - |
| author_login | TEXT | Author username | Renamed from user_login |
| author_id | BIGINT | Author user ID | Renamed from user_id |
| comment_body | TEXT | Comment content | Renamed from body |
| comment_length | INTEGER | Comment length | Calculated |
| created_at | TIMESTAMP | Creation timestamp | Cast to timestamp |

### staging.stg_commits
Cleaned commit data.

| Column | Type | Description | Transformation |
|--------|------|-------------|----------------|
| commit_sha | TEXT | Commit SHA (PK) | Renamed from sha |
| author_login | TEXT | GitHub author | - |
| author_id | BIGINT | GitHub author ID | - |
| commit_author_name | TEXT | Git author name | - |
| commit_author_email | TEXT | Git author email | - |
| commit_message | TEXT | Commit message | Renamed from message |
| message_length | INTEGER | Message length | Calculated |
| commit_date | TIMESTAMP | Commit timestamp | Cast to timestamp |

### staging.stg_releases
Cleaned release data.

| Column | Type | Description | Transformation |
|--------|------|-------------|----------------|
| release_id | BIGINT | Release ID (PK) | Renamed from id |
| tag_name | TEXT | Release tag | - |
| release_name | TEXT | Release name | Renamed from name |
| is_draft | BOOLEAN | Draft flag | Renamed from draft |
| is_prerelease | BOOLEAN | Prerelease flag | Renamed from prerelease |
| author_login | TEXT | Release author | - |
| published_at | TIMESTAMP | Publication timestamp | Cast to timestamp |

### staging.stg_stargazers
Cleaned stargazer data.

| Column | Type | Description | Transformation |
|--------|------|-------------|----------------|
| user_id | BIGINT | User ID | - |
| user_login | TEXT | Username | - |
| repository_full_name | TEXT | Repository | - |
| starred_at | TIMESTAMP | Star timestamp | Cast to timestamp |

### staging.stg_users
Deduplicated user data from all sources.

| Column | Type | Description | Transformation |
|--------|------|-------------|----------------|
| user_id | BIGINT | User ID (PK) | - |
| user_login | TEXT | Username | - |
| is_bot | BOOLEAN | Bot detection flag | Calculated from username patterns |

---

## Silver Layer (Intermediate)

### intermediate.int_issue_lifecycle
Issues enriched with lifecycle metrics.

| Column | Type | Description | Calculation |
|--------|------|-------------|-------------|
| issue_id | BIGINT | Issue ID | From stg_issues |
| comment_count | INTEGER | Number of comments | Aggregated from comments |
| time_to_close_hours | DECIMAL | Hours to close | datediff(created_at, closed_at) |
| time_to_first_response_hours | DECIMAL | Hours to first comment | datediff(created_at, first_comment_at) |
| is_closed | BOOLEAN | Closed flag | closed_at IS NOT NULL |
| is_bug | BOOLEAN | Bug label present | 'bug' in label_list |
| is_enhancement | BOOLEAN | Enhancement label present | 'enhancement' or 'feature' in label_list |

### intermediate.int_pr_with_reviews
Pull requests enriched with review and comment data.

| Column | Type | Description | Calculation |
|--------|------|-------------|-------------|
| pull_request_id | BIGINT | PR ID | From stg_pull_requests |
| comment_count | INTEGER | Number of comments | Aggregated from comments |
| time_to_merge_hours | DECIMAL | Hours to merge | datediff(created_at, merged_at) |
| time_to_first_comment_hours | DECIMAL | Hours to first comment | datediff(created_at, first_comment_at) |
| is_closed_without_merge | BOOLEAN | Closed but not merged | closed_at IS NOT NULL AND merged_at IS NULL |

### intermediate.int_contributor_activity
Unified activity stream across all contribution types.

| Column | Type | Description | Source |
|--------|------|-------------|--------|
| user_id | BIGINT | Contributor user ID | From all activity sources |
| user_login | TEXT | Username | From all activity sources |
| activity_type | TEXT | Type of activity | 'issue_created', 'pr_created', 'comment_created', 'commit_created' |
| activity_at | TIMESTAMP | Activity timestamp | Varies by type |
| activity_id | TEXT | Activity identifier | Issue ID, PR ID, Comment ID, or Commit SHA |
| is_bot | BOOLEAN | Bot flag | From stg_users |
| activity_date | DATE | Activity date | date_trunc('day', activity_at) |
| activity_month | DATE | Activity month | date_trunc('month', activity_at) |

---

## Gold Layer (Dimensions)

### marts.dim_repositories
Repository dimension table.

| Column | Type | Description | Business Key |
|--------|------|-------------|--------------|
| repo_key | TEXT | Surrogate key (PK) | Generated hash |
| repository_id | BIGINT | Natural key | GitHub repository ID |
| repository_full_name | TEXT | Full name | owner/repo |
| repository_name | TEXT | Repository name | - |
| owner_login | TEXT | Owner username | - |
| primary_language | TEXT | Primary language | - |
| stargazers_count | INTEGER | Star count (snapshot) | - |
| forks_count | INTEGER | Fork count (snapshot) | - |
| is_archived | BOOLEAN | Archived flag | - |
| created_at | TIMESTAMP | Creation timestamp | - |

### marts.dim_users
User dimension table.

| Column | Type | Description | Business Key |
|--------|------|-------------|--------------|
| user_key | TEXT | Surrogate key (PK) | Generated hash |
| user_id | BIGINT | Natural key | GitHub user ID |
| user_login | TEXT | Username | - |
| is_bot | BOOLEAN | Bot detection flag | - |

### marts.dim_dates
Date dimension table.

| Column | Type | Description | Range |
|--------|------|-------------|-------|
| date_key | INTEGER | Surrogate key (PK) YYYYMMDD | 20200101-20261231 |
| date | DATE | Calendar date | 2020-01-01 to 2026-12-31 |
| year | INTEGER | Year | 2020-2026 |
| quarter | INTEGER | Quarter | 1-4 |
| month | INTEGER | Month | 1-12 |
| week_of_year | INTEGER | Week number | 1-53 |
| day_of_week | INTEGER | Day of week | 0=Sunday, 6=Saturday |
| month_name | TEXT | Month name | January-December |
| day_name | TEXT | Day name | Sunday-Saturday |
| is_weekend | BOOLEAN | Weekend flag | Saturday or Sunday |

---

## Gold Layer (Facts)

### marts.fct_pull_requests
Pull request fact table.

| Column | Type | Description | Grain |
|--------|------|-------------|-------|
| pr_key | TEXT | Surrogate key (PK) | One row per pull request |
| pull_request_id | BIGINT | Natural key | GitHub PR ID |
| pr_number | INTEGER | PR number | Within repository |
| repo_key | TEXT | Repository FK | → dim_repositories |
| author_key | TEXT | Author FK | → dim_users |
| created_date_key | INTEGER | Creation date FK | → dim_dates |
| merged_date_key | INTEGER | Merge date FK | → dim_dates |
| closed_date_key | INTEGER | Close date FK | → dim_dates |
| is_merged | BOOLEAN | Merged flag | - |
| is_draft | BOOLEAN | Draft flag | - |
| comment_count | INTEGER | Number of comments | - |
| time_to_merge_hours | DECIMAL | Hours to merge | Nullable if not merged |
| time_to_first_comment_hours | DECIMAL | Hours to first comment | Nullable if no comments |

### marts.fct_issues
Issue fact table.

| Column | Type | Description | Grain |
|--------|------|-------------|-------|
| issue_key | TEXT | Surrogate key (PK) | One row per issue |
| issue_id | BIGINT | Natural key | GitHub issue ID |
| issue_number | INTEGER | Issue number | Within repository |
| repo_key | TEXT | Repository FK | → dim_repositories |
| author_key | TEXT | Author FK | → dim_users |
| created_date_key | INTEGER | Creation date FK | → dim_dates |
| closed_date_key | INTEGER | Close date FK | → dim_dates |
| is_closed | BOOLEAN | Closed flag | - |
| is_bug | BOOLEAN | Bug label flag | - |
| is_enhancement | BOOLEAN | Enhancement label flag | - |
| comment_count | INTEGER | Number of comments | - |
| time_to_close_hours | DECIMAL | Hours to close | Nullable if open |
| time_to_first_response_hours | DECIMAL | Hours to first response | Nullable if no comments |

### marts.fct_commits
Commit fact table.

| Column | Type | Description | Grain |
|--------|------|-------------|-------|
| commit_key | TEXT | Surrogate key (PK) | One row per commit |
| commit_sha | TEXT | Natural key | Git commit SHA |
| repo_key | TEXT | Repository FK | → dim_repositories |
| author_key | TEXT | Author FK | → dim_users |
| commit_date_key | INTEGER | Commit date FK | → dim_dates |
| commit_message | TEXT | Commit message | - |
| message_length | INTEGER | Message length | - |
| commit_author_name | TEXT | Git author name | - |
| commit_author_email | TEXT | Git author email | - |

### marts.fct_stargazers
Stargazer fact table (accumulating snapshot).

| Column | Type | Description | Grain |
|--------|------|-------------|-------|
| stargazer_key | TEXT | Surrogate key (PK) | One row per user-repo star |
| repo_key | TEXT | Repository FK | → dim_repositories |
| user_key | TEXT | User FK | → dim_users |
| starred_date_key | INTEGER | Star date FK | → dim_dates |
| starred_at | TIMESTAMP | Star timestamp | - |

---

## Gold Layer (Metrics)

### marts.pr_cycle_time
PR cycle time metrics aggregated by period.

| Column | Type | Description | Grain |
|--------|------|-------------|-------|
| period_type | TEXT | Period type | 'weekly' or 'monthly' |
| repository_name | TEXT | Repository name | - |
| year | INTEGER | Year | - |
| period_number | INTEGER | Week or month number | - |
| merged_pr_count | INTEGER | Number of merged PRs | - |
| avg_hours_to_merge | DECIMAL | Average hours to merge | - |
| median_hours_to_merge | DECIMAL | Median hours to merge | - |
| p90_hours_to_merge | DECIMAL | 90th percentile hours | - |
| avg_days_to_merge | DECIMAL | Average days to merge | hours / 24 |
| median_days_to_merge | DECIMAL | Median days to merge | hours / 24 |
| p90_days_to_merge | DECIMAL | 90th percentile days | hours / 24 |

### marts.contributor_engagement
Contributor engagement metrics by month.

| Column | Type | Description | Grain |
|--------|------|-------------|-------|
| repository_full_name | TEXT | Repository | One row per repo-month |
| year | INTEGER | Year | - |
| month | INTEGER | Month | - |
| unique_contributors | INTEGER | Distinct contributors | - |
| new_contributors | INTEGER | First-time contributors | - |
| returning_contributors | INTEGER | Returning contributors | - |
| total_activities | INTEGER | Total activities | - |
| commit_count | INTEGER | Number of commits | - |
| pr_count | INTEGER | Number of PRs | - |
| issue_count | INTEGER | Number of issues | - |
| comment_count | INTEGER | Number of comments | - |
| activities_per_contributor | DECIMAL | Avg activities per person | total / unique |
| returning_contributor_pct | DECIMAL | % returning contributors | (returning / unique) * 100 |

### marts.release_velocity
Release velocity and cadence metrics.

| Column | Type | Description | Grain |
|--------|------|-------------|-------|
| period_type | TEXT | Period type | 'monthly' or 'quarterly' |
| repository_name | TEXT | Repository name | - |
| year | INTEGER | Year | - |
| period_number | INTEGER | Month or quarter number | - |
| release_count | INTEGER | Number of releases | - |
| stable_release_count | INTEGER | Non-prerelease count | - |
| avg_days_between_releases | DECIMAL | Avg days between releases | - |
| median_days_between_releases | DECIMAL | Median days between releases | - |
| releases_per_period | DECIMAL | Release cadence | - |

---

## Relationships

### Primary Keys
- All dimension tables have surrogate keys (generated hashes)
- All fact tables have surrogate keys
- All natural keys are preserved

### Foreign Keys
- **fct_pull_requests** → dim_repositories (repo_key)
- **fct_pull_requests** → dim_users (author_key)
- **fct_pull_requests** → dim_dates (created_date_key, merged_date_key, closed_date_key)
- **fct_issues** → dim_repositories (repo_key)
- **fct_issues** → dim_users (author_key)
- **fct_issues** → dim_dates (created_date_key, closed_date_key)
- **fct_commits** → dim_repositories (repo_key)
- **fct_commits** → dim_users (author_key)
- **fct_commits** → dim_dates (commit_date_key)
- **fct_stargazers** → dim_repositories (repo_key)
- **fct_stargazers** → dim_users (user_key)
- **fct_stargazers** → dim_dates (starred_date_key)

### Referential Integrity
All foreign key relationships are enforced via dbt `relationships` tests.

---

## Data Types

### Common Patterns
- **IDs**: BIGINT (GitHub IDs), TEXT (surrogate keys)
- **Timestamps**: TIMESTAMP (UTC)
- **Dates**: DATE
- **Flags**: BOOLEAN
- **Counts**: INTEGER
- **Metrics**: DECIMAL
- **Text**: TEXT (variable length)
- **Arrays**: ARRAY (for labels, topics)

### Naming Conventions
- **Snake_case**: All column names
- **Suffixes**: 
  - `_id`: Natural keys
  - `_key`: Surrogate keys
  - `_at`: Timestamps
  - `_count`: Counts
  - `_pct`: Percentages
  - `is_`: Boolean flags
- **Prefixes**:
  - `avg_`: Averages
  - `median_`: Medians
  - `p##_`: Percentiles

---

## Glossary

- **Surrogate Key**: System-generated unique identifier (hash)
- **Natural Key**: Business identifier from source system
- **Grain**: Level of detail in a fact table
- **Dimension**: Descriptive attributes for analysis
- **Fact**: Measurable events or transactions
- **Metric**: Pre-aggregated measure
- **Bot**: Automated user account (detected by username patterns)
- **Cycle Time**: Time from creation to completion
- **Engagement**: User activity and participation
- **Velocity**: Rate of change over time
