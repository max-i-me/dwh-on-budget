-- Assert that all merged PRs have positive or zero cycle time
-- Negative cycle times indicate data quality issues

select
    pr_key,
    pull_request_id,
    time_to_merge_hours
from {{ ref('fct_pull_requests') }}
where is_merged = true
    and time_to_merge_hours is not null
    and time_to_merge_hours < 0
