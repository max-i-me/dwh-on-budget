-- GitHub Analytics Data Warehouse - Example Queries
-- This file contains example queries to explore the data warehouse

-- ============================================================================
-- Repository Overview
-- ============================================================================

-- Get repository statistics
SELECT 
    repository_name,
    repository_full_name,
    primary_language,
    stargazers_count,
    forks_count,
    open_issues_count,
    created_at,
    pushed_at
FROM marts.dim_repositories
ORDER BY stargazers_count DESC;

-- ============================================================================
-- Pull Request Analysis
-- ============================================================================

-- PR cycle time by repository
SELECT 
    r.repository_name,
    COUNT(*) as total_merged_prs,
    ROUND(AVG(f.time_to_merge_hours), 2) as avg_hours_to_merge,
    ROUND(MEDIAN(f.time_to_merge_hours), 2) as median_hours_to_merge,
    ROUND(AVG(f.time_to_merge_hours) / 24, 2) as avg_days_to_merge,
    ROUND(MEDIAN(f.time_to_merge_hours) / 24, 2) as median_days_to_merge
FROM marts.fct_pull_requests f
JOIN marts.dim_repositories r ON f.repo_key = r.repo_key
WHERE f.is_merged = true
    AND f.time_to_merge_hours IS NOT NULL
GROUP BY r.repository_name
ORDER BY median_hours_to_merge;

-- PR merge rate by repository
SELECT 
    r.repository_name,
    COUNT(*) as total_prs,
    SUM(CASE WHEN f.is_merged THEN 1 ELSE 0 END) as merged_prs,
    ROUND(SUM(CASE WHEN f.is_merged THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as merge_rate_pct
FROM marts.fct_pull_requests f
JOIN marts.dim_repositories r ON f.repo_key = r.repo_key
GROUP BY r.repository_name
ORDER BY merge_rate_pct DESC;

-- PRs with longest time to merge
SELECT 
    r.repository_name,
    f.pr_number,
    f.pr_title,
    u.user_login as author,
    f.created_at,
    f.merged_at,
    ROUND(f.time_to_merge_hours / 24, 2) as days_to_merge
FROM marts.fct_pull_requests f
JOIN marts.dim_repositories r ON f.repo_key = r.repo_key
JOIN marts.dim_users u ON f.author_key = u.user_key
WHERE f.is_merged = true
ORDER BY f.time_to_merge_hours DESC
LIMIT 20;

-- ============================================================================
-- Issue Analysis
-- ============================================================================

-- Issue resolution time by repository
SELECT 
    r.repository_name,
    COUNT(*) as total_closed_issues,
    ROUND(AVG(f.time_to_close_hours), 2) as avg_hours_to_close,
    ROUND(MEDIAN(f.time_to_close_hours), 2) as median_hours_to_close,
    ROUND(AVG(f.time_to_close_hours) / 24, 2) as avg_days_to_close,
    ROUND(MEDIAN(f.time_to_close_hours) / 24, 2) as median_days_to_close
FROM marts.fct_issues f
JOIN marts.dim_repositories r ON f.repo_key = r.repo_key
WHERE f.is_closed = true
    AND f.time_to_close_hours IS NOT NULL
GROUP BY r.repository_name
ORDER BY median_hours_to_close;

-- Bug vs enhancement issues
SELECT 
    r.repository_name,
    COUNT(*) as total_issues,
    SUM(CASE WHEN f.is_bug THEN 1 ELSE 0 END) as bug_issues,
    SUM(CASE WHEN f.is_enhancement THEN 1 ELSE 0 END) as enhancement_issues,
    ROUND(SUM(CASE WHEN f.is_bug THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as bug_pct,
    ROUND(SUM(CASE WHEN f.is_enhancement THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as enhancement_pct
FROM marts.fct_issues f
JOIN marts.dim_repositories r ON f.repo_key = r.repo_key
GROUP BY r.repository_name;

-- ============================================================================
-- Contributor Analysis
-- ============================================================================

-- Top contributors by total activity
SELECT 
    u.user_login,
    u.is_bot,
    COUNT(*) as total_activities,
    COUNT(DISTINCT a.activity_type) as activity_types,
    COUNT(DISTINCT a.repository_full_name) as repos_contributed_to,
    MIN(a.activity_at) as first_activity,
    MAX(a.activity_at) as last_activity
FROM intermediate.int_contributor_activity a
JOIN marts.dim_users u ON a.user_id = u.user_id
WHERE u.is_bot = false
GROUP BY u.user_login, u.is_bot
ORDER BY total_activities DESC
LIMIT 20;

-- Contributor activity breakdown
SELECT 
    u.user_login,
    SUM(CASE WHEN a.activity_type = 'commit_created' THEN 1 ELSE 0 END) as commits,
    SUM(CASE WHEN a.activity_type = 'pr_created' THEN 1 ELSE 0 END) as prs,
    SUM(CASE WHEN a.activity_type = 'issue_created' THEN 1 ELSE 0 END) as issues,
    SUM(CASE WHEN a.activity_type = 'comment_created' THEN 1 ELSE 0 END) as comments,
    COUNT(*) as total_activities
FROM intermediate.int_contributor_activity a
JOIN marts.dim_users u ON a.user_id = u.user_id
WHERE u.is_bot = false
GROUP BY u.user_login
ORDER BY total_activities DESC
LIMIT 20;

-- ============================================================================
-- Time Series Analysis
-- ============================================================================

-- Repository growth over time (cumulative stars)
SELECT 
    d.date,
    r.repository_name,
    COUNT(*) as new_stars,
    SUM(COUNT(*)) OVER (
        PARTITION BY r.repository_name 
        ORDER BY d.date 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as cumulative_stars
FROM marts.fct_stargazers s
JOIN marts.dim_dates d ON s.starred_date_key = d.date_key
JOIN marts.dim_repositories r ON s.repo_key = r.repo_key
GROUP BY d.date, r.repository_name
ORDER BY r.repository_name, d.date;

-- Monthly PR activity
SELECT 
    d.year,
    d.month,
    r.repository_name,
    COUNT(*) as prs_created,
    SUM(CASE WHEN f.is_merged THEN 1 ELSE 0 END) as prs_merged,
    ROUND(AVG(f.time_to_merge_hours) / 24, 2) as avg_days_to_merge
FROM marts.fct_pull_requests f
JOIN marts.dim_dates d ON f.created_date_key = d.date_key
JOIN marts.dim_repositories r ON f.repo_key = r.repo_key
GROUP BY d.year, d.month, r.repository_name
ORDER BY d.year, d.month, r.repository_name;

-- ============================================================================
-- Metric Views
-- ============================================================================

-- PR cycle time trends (from metric view)
SELECT 
    repository_name,
    period_type,
    year,
    period_number,
    merged_pr_count,
    median_days_to_merge,
    p90_days_to_merge
FROM marts.pr_cycle_time
WHERE period_type = 'monthly'
ORDER BY repository_name, year, period_number;

-- Contributor engagement trends (from metric view)
SELECT 
    repository_full_name,
    year,
    month,
    unique_contributors,
    new_contributors,
    returning_contributors,
    ROUND(returning_contributor_pct, 2) as returning_pct,
    total_activities,
    ROUND(activities_per_contributor, 2) as activities_per_contributor
FROM marts.contributor_engagement
ORDER BY repository_full_name, year, month;

-- Release velocity (from metric view)
SELECT 
    repository_name,
    period_type,
    year,
    period_number,
    release_count,
    stable_release_count,
    ROUND(avg_days_between_releases, 1) as avg_days_between_releases,
    ROUND(median_days_between_releases, 1) as median_days_between_releases
FROM marts.release_velocity
WHERE period_type = 'monthly'
ORDER BY repository_name, year, period_number;

-- ============================================================================
-- Advanced Analytics
-- ============================================================================

-- Contributor retention analysis
WITH first_activity AS (
    SELECT 
        user_id,
        repository_full_name,
        MIN(DATE_TRUNC('month', activity_at)) as first_month
    FROM intermediate.int_contributor_activity
    WHERE is_bot = false
    GROUP BY user_id, repository_full_name
),
monthly_activity AS (
    SELECT 
        a.user_id,
        a.repository_full_name,
        DATE_TRUNC('month', a.activity_at) as activity_month,
        COUNT(*) as activity_count
    FROM intermediate.int_contributor_activity a
    WHERE a.is_bot = false
    GROUP BY a.user_id, a.repository_full_name, DATE_TRUNC('month', a.activity_at)
)
SELECT 
    m.repository_full_name,
    m.activity_month,
    COUNT(DISTINCT m.user_id) as active_contributors,
    COUNT(DISTINCT CASE WHEN f.first_month = m.activity_month THEN m.user_id END) as new_contributors,
    COUNT(DISTINCT CASE WHEN f.first_month < m.activity_month THEN m.user_id END) as returning_contributors
FROM monthly_activity m
JOIN first_activity f ON m.user_id = f.user_id AND m.repository_full_name = f.repository_full_name
GROUP BY m.repository_full_name, m.activity_month
ORDER BY m.repository_full_name, m.activity_month;

-- PR review responsiveness
SELECT 
    r.repository_name,
    COUNT(*) as total_prs,
    COUNT(CASE WHEN f.time_to_first_comment_hours IS NOT NULL THEN 1 END) as prs_with_comments,
    ROUND(AVG(f.time_to_first_comment_hours), 2) as avg_hours_to_first_comment,
    ROUND(MEDIAN(f.time_to_first_comment_hours), 2) as median_hours_to_first_comment,
    ROUND(AVG(f.time_to_first_comment_hours) / 24, 2) as avg_days_to_first_comment
FROM marts.fct_pull_requests f
JOIN marts.dim_repositories r ON f.repo_key = r.repo_key
WHERE f.time_to_first_comment_hours IS NOT NULL
GROUP BY r.repository_name
ORDER BY median_hours_to_first_comment;
