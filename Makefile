.PHONY: extract transform test docs run clean setup install

include .env
export

# Setup virtual environment and install dependencies
setup:
	python3 -m venv .venv
	@echo "Virtual environment created. Run 'source .venv/bin/activate' to activate it."

# Install dependencies
install:
	pip install --upgrade pip
	pip install -r requirements.txt
	cd transform && dbt deps

# Extract data from GitHub API using dlt
extract:
	cd extract && python github_pipeline.py

# Transform data using dbt
transform:
	cd transform && dbt run

# Run dbt tests
test:
	cd transform && dbt test

# Generate and serve dbt documentation
docs:
	cd transform && dbt docs generate && dbt docs serve

# Run full pipeline: extract -> transform -> test
run: extract transform test

# Clean database and generated files
clean:
	rm -f dwhonbudget.duckdb dwhonbudget.duckdb.wal
	rm -rf transform/target transform/logs transform/dbt_packages
	rm -rf extract/.dlt/.sources

# Full reset: clean and reinstall
reset: clean
	rm -rf .venv
