"""
GitHub REST API source for dlt.

This module implements extraction logic for 9 GitHub entity types:
- Repositories (metadata)
- Issues (excluding PRs)
- Pull Requests
- PR Reviews (child resource)
- Issue/PR Comments
- Commits
- Releases
- Stargazers (with timestamps)
- Contributors

Each resource implements appropriate incremental strategies:
- Merge: Issues, PRs, Comments, Releases
- Append: Commits, Stargazers, PR Reviews
- Replace: Repositories, Contributors
"""

import dlt
from dlt.sources.helpers import requests
from typing import Iterator, Optional
from datetime import datetime, timezone


def _get_headers(access_token: str, accept: str = "application/vnd.github+json") -> dict:
    """Generate GitHub API request headers."""
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
    """
    Paginate through GitHub API results.
    
    Yields individual items from paginated responses.
    """
    params = params or {}
    params["per_page"] = per_page
    params["page"] = 1
    
    while True:
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()
        
        data = response.json()
        
        # Handle empty response
        if not data:
            break
        
        # Yield each item
        for item in data:
            yield item
        
        # Check if there are more pages
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
        owner: Repository owner (user or organization)
        repo: Repository name
        access_token: GitHub Personal Access Token (from secrets.toml)
        initial_date: date to extract from

    Returns:
        List of dlt resources for extraction
    """
    
    base_url = f"https://api.github.com/repos/{owner}/{repo}"
    
    @dlt.resource(
        name="repositories",
        write_disposition="replace",
        primary_key="id",
    )
    def repositories() -> Iterator[dict]:
        """Extract repository metadata (full refresh)."""
        headers = _get_headers(access_token)
        response = requests.get(base_url, headers=headers)
        response.raise_for_status()
        
        repo_data = response.json()
        
        # Add explicit owner/repo for easier filtering
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
        """
        Extract issues (excluding PRs).
        
        Incremental: Merge on updated_at.
        Note: GitHub's /issues endpoint returns both issues AND PRs.
        We filter PRs in dbt staging layer.
        """
        headers = _get_headers(access_token)
        url = f"{base_url}/issues"
        
        params = {
            "state": "all",  # Get both open and closed
            "sort": "updated",
            "direction": "asc",
            "since": updated_at.last_value,
        }
        
        for issue in _paginate_github_api(url, headers, params):
            # Add repo context
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
        """
        Extract pull requests.
        
        Incremental: Merge on updated_at.
        """
        headers = _get_headers(access_token)
        url = f"{base_url}/pulls"
        
        params = {
            "state": "all",
            "sort": "updated",
            "direction": "asc",
        }
        
        for pr in _paginate_github_api(url, headers, params):
            # Filter by incremental cursor
            if pr["updated_at"] < updated_at.last_value:
                continue
            
            # Add repo context
            pr["_owner"] = owner
            pr["_repo"] = repo
            
            yield pr
    
    @dlt.resource(
        name="pr_reviews",
        write_disposition="append",
        primary_key="id",
    )
    def pr_reviews() -> Iterator[dict]:
        """
        Extract PR reviews (child resource of pull_requests).
        
        Append-only: Reviews are immutable once submitted.
        Note: This requires iterating through all PRs to get reviews.
        
        WARNING: PR reviews may not be accessible on public repos where you're
        not a collaborator. This resource will skip inaccessible PRs.
        """
        headers = _get_headers(access_token)
        
        # First, get all PR numbers
        prs_url = f"{base_url}/pulls"
        pr_numbers = []
        
        for pr in _paginate_github_api(prs_url, headers, {"state": "all"}):
            pr_numbers.append(pr["number"])
        
        # Track statistics
        accessible_count = 0
        forbidden_count = 0
        
        # Then get reviews for each PR
        for pr_number in pr_numbers:
            reviews_url = f"{base_url}/pulls/{pr_number}/reviews"
            
            try:
                for review in _paginate_github_api(reviews_url, headers):
                    # Add context
                    review["_owner"] = owner
                    review["_repo"] = repo
                    review["_pr_number"] = pr_number
                    
                    accessible_count += 1
                    yield review
            except requests.HTTPError as e:
                # Skip PRs that don't have reviews or are inaccessible
                if e.response.status_code == 404:
                    # PR has no reviews
                    continue
                elif e.response.status_code == 403:
                    # Forbidden - likely not a collaborator on public repo
                    forbidden_count += 1
                    continue
                else:
                    # Other errors should be raised
                    raise
        
        # Log summary
        print(f"   PR Reviews: {accessible_count} accessible, {forbidden_count} forbidden (not a collaborator)")
    
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
        """
        Extract issue and PR comments.
        
        Incremental: Merge on updated_at.
        """
        headers = _get_headers(access_token)
        url = f"{base_url}/issues/comments"
        
        params = {
            "sort": "updated",
            "direction": "asc",
            "since": updated_at.last_value,
        }
        
        for comment in _paginate_github_api(url, headers, params):
            # Add repo context
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
        """
        Extract commits.
        
        Append-only: Commits are immutable.
        Incremental on committer.date (not author.date for consistency).
        """
        headers = _get_headers(access_token)
        url = f"{base_url}/commits"
        
        params = {
            "since": committer_date.last_value,
        }
        
        for commit in _paginate_github_api(url, headers, params):
            # Add repo context
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
        """
        Extract releases.
        
        Incremental: Merge on published_at.
        """
        headers = _get_headers(access_token)
        url = f"{base_url}/releases"
        
        for release in _paginate_github_api(url, headers):
            # Filter by incremental cursor (published_at can be null for drafts)
            if release.get("published_at") and release["published_at"] < published_at.last_value:
                continue
            
            # Add repo context
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
        """
        Extract stargazers with timestamps.
        
        Append-only: Stars are events.
        Requires special Accept header to get starred_at timestamp.
        """
        # Special header for timestamp data
        headers = _get_headers(access_token, accept="application/vnd.github.star+json")
        url = f"{base_url}/stargazers"
        
        for star_event in _paginate_github_api(url, headers):
            # Filter by incremental cursor
            if star_event["starred_at"] < starred_at.last_value:
                continue
            
            # Flatten structure
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
        """
        Extract repository contributors.
        
        Full refresh: Contribution counts change frequently.
        """
        headers = _get_headers(access_token)
        url = f"{base_url}/contributors"
        
        for contributor in _paginate_github_api(url, headers):
            # Flatten structure
            contrib_data = {
                "user_id": contributor["id"],
                "user_login": contributor["login"],
                "user_type": contributor["type"],
                "contributions": contributor["contributions"],
                "_owner": owner,
                "_repo": repo,
            }
            
            yield contrib_data
    
    # Return all resources
    return [
        repositories,
        issues,
        pull_requests,
        pr_reviews,
        issue_comments,
        commits,
        releases,
        stargazers,
        contributors,
    ]
