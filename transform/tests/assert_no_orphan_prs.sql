-- Assert that all PRs in the fact table have valid repository references
-- This test ensures referential integrity

select
    pr_key,
    repo_key
from {{ ref('fct_pull_requests') }}
where repo_key is null
