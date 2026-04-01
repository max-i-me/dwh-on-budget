"""
GitHub REST API source for dlt.
Extracts 9 entity types: repositories, issues, PRs, PR reviews, comments, commits, releases, stargazers, contributors.
"""

import dlt
from dlt.sources.helpers import requests
from typing import Iterator, Optional
from datetime import datetime, timezone


def _get_headers(access_token: str, accept: str = "application/vnd.github+json") -> dict:
    return {
        "Authorization": f"Bearer {access_token}",
        "Accept": accept,
        "X-GitHub-Api-Version": "2022-11-28",
    }


def _paginate_github_api(
    url: str,
    headers: dict,
    params: Optional[dict] = None,
    per_page: int = 100,
) -> Iterator[dict]:
    """Paginate through GitHub API results."""
    params = params or {}
    params["per_page"] = per_page
    params["page"] = 1
    
    while True:
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()
        
        data = response.json()
        if not data:
            break
        
        for item in data:
            yield item
        
        if len(data) < per_page:
            break
        
        params["page"] += 1


@dlt.source(name="github")
def github_source(
    owner: str,
    repo: str,
    access_token: str = dlt.secrets.value,
    initial_date: str = "2025-01-01T00:00:00Z"
) -> list:
    """
    Main GitHub data source.
    
    Args:
        owner: Repository owner
        repo: Repository name
        access_token: GitHub Personal Access Token
        initial_date: Start date for incremental extraction
    """
    
    base_url = f"https://api.github.com/repos/{owner}/{repo}"
    
    @dlt.resource(
        name="repositories",
        write_disposition="replace",
        primary_key="id",
    )
    def repositories() -> Iterator[dict]:
        """Extract repository metadata."""
        headers = _get_headers(access_token)
        response = requests.get(base_url, headers=headers)
        response.raise_for_status()
        
        repo_data = response.json()
        repo_data["_owner"] = owner
        repo_data["_repo"] = repo
        
        yield repo_data
    
    @dlt.resource(
        name="issues",
        write_disposition="merge",
        primary_key="id",
    )
    def issues(
        updated_at: dlt.sources.incremental[str] = dlt.sources.incremental(
            "updated_at",
            initial_value=initial_date,
        )
    ) -> Iterator[dict]:
        """Extract issues (excludes PRs, filtered in dbt)."""
        headers = _get_headers(access_token)
        url = f"{base_url}/issues"
        
        params = {
            "state": "all",
            "sort": "updated",
            "direction": "asc",
            "since": updated_at.last_value,
        }
        
        for issue in _paginate_github_api(url, headers, params):
            issue["_owner"] = owner
            issue["_repo"] = repo
            yield issue
    
    @dlt.resource(
        name="pull_requests",
        write_disposition="merge",
        primary_key="id",
    )
    def pull_requests(
        updated_at: dlt.sources.incremental[str] = dlt.sources.incremental(
            "updated_at",
            initial_value=initial_date,
        )
    ) -> Iterator[dict]:
        """Extract pull requests."""
        headers = _get_headers(access_token)
        url = f"{base_url}/pulls"
        
        params = {
            "state": "all",
            "sort": "updated",
            "direction": "asc",
        }
        
        for pr in _paginate_github_api(url, headers, params):
            if pr["updated_at"] < updated_at.last_value:
                continue
            
            pr["_owner"] = owner
            pr["_repo"] = repo
            yield pr
    
    @dlt.resource(
        name="pr_reviews",
        write_disposition="append",
        primary_key="id",
    )
    def pr_reviews() -> Iterator[dict]:
        """Extract PR reviews. Append-only since reviews are immutable."""
        headers = _get_headers(access_token)
        
        prs_url = f"{base_url}/pulls"
        pr_numbers = []
        
        for pr in _paginate_github_api(prs_url, headers, {"state": "all"}):
            pr_numbers.append(pr["number"])
        
        accessible_count = 0
        forbidden_count = 0
        
        for pr_number in pr_numbers:
            reviews_url = f"{base_url}/pulls/{pr_number}/reviews"
            
            try:
                for review in _paginate_github_api(reviews_url, headers):
                    review["_owner"] = owner
                    review["_repo"] = repo
                    review["_pr_number"] = pr_number
                    
                    accessible_count += 1
                    yield review
            except requests.HTTPError as e:
                if e.response.status_code == 404:
                    continue
                elif e.response.status_code == 403:
                    forbidden_count += 1
                    continue
                else:
                    raise
        
        print(f"   PR Reviews: {accessible_count} accessible, {forbidden_count} forbidden")
    
    @dlt.resource(
        name="issue_comments",
        write_disposition="merge",
        primary_key="id",
    )
    def issue_comments(
        updated_at: dlt.sources.incremental[str] = dlt.sources.incremental(
            "updated_at",
            initial_value=initial_date,
        )
    ) -> Iterator[dict]:
        """Extract issue and PR comments."""
        headers = _get_headers(access_token)
        url = f"{base_url}/issues/comments"
        
        params = {
            "sort": "updated",
            "direction": "asc",
            "since": updated_at.last_value,
        }
        
        for comment in _paginate_github_api(url, headers, params):
            comment["_owner"] = owner
            comment["_repo"] = repo
            yield comment
    
    @dlt.resource(
        name="commits",
        write_disposition="append",
        primary_key="sha",
    )
    def commits(
        committer_date: dlt.sources.incremental[str] = dlt.sources.incremental(
            "commit.committer.date",
            initial_value=initial_date,
        )
    ) -> Iterator[dict]:
        """Extract commits. Append-only since commits are immutable."""
        headers = _get_headers(access_token)
        url = f"{base_url}/commits"
        
        params = {
            "since": committer_date.last_value,
        }
        
        for commit in _paginate_github_api(url, headers, params):
            commit["_owner"] = owner
            commit["_repo"] = repo
            yield commit
    
    @dlt.resource(
        name="releases",
        write_disposition="merge",
        primary_key="id",
    )
    def releases(
        published_at: dlt.sources.incremental[str] = dlt.sources.incremental(
            "published_at",
            initial_value=initial_date,
        )
    ) -> Iterator[dict]:
        """Extract releases."""
        headers = _get_headers(access_token)
        url = f"{base_url}/releases"
        
        for release in _paginate_github_api(url, headers):
            if release.get("published_at") and release["published_at"] < published_at.last_value:
                continue
            
            release["_owner"] = owner
            release["_repo"] = repo
            yield release
    
    @dlt.resource(
        name="stargazers",
        write_disposition="append",
        primary_key=["user_id", "starred_at"],
    )
    def stargazers(
        starred_at: dlt.sources.incremental[str] = dlt.sources.incremental(
            "starred_at",
            initial_value=initial_date,
        )
    ) -> Iterator[dict]:
        """Extract stargazers with timestamps. Requires special Accept header."""
        headers = _get_headers(access_token, accept="application/vnd.github.star+json")
        url = f"{base_url}/stargazers"
        
        for star_event in _paginate_github_api(url, headers):
            if star_event["starred_at"] < starred_at.last_value:
                continue
            
            star_data = {
                "starred_at": star_event["starred_at"],
                "user_id": star_event["user"]["id"],
                "user_login": star_event["user"]["login"],
                "user_type": star_event["user"]["type"],
                "_owner": owner,
                "_repo": repo,
            }
            
            yield star_data
    
    @dlt.resource(
        name="contributors",
        write_disposition="replace",
        primary_key=["user_id", "_owner", "_repo"],
    )
    def contributors() -> Iterator[dict]:
        """Extract repository contributors. Full refresh since counts change frequently."""
        headers = _get_headers(access_token)
        url = f"{base_url}/contributors"
        
        for contributor in _paginate_github_api(url, headers):
            contrib_data = {
                "user_id": contributor["id"],
                "user_login": contributor["login"],
                "user_type": contributor["type"],
                "contributions": contributor["contributions"],
                "_owner": owner,
                "_repo": repo,
            }
            
            yield contrib_data
    
    return [
        repositories,
        issues,
        pull_requests,
        #pr_reviews, # Disabled due to rate limiting
        issue_comments,
        commits,
        releases,
        stargazers,
        contributors,
    ]
