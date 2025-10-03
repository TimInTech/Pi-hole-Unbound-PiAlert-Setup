#!/usr/bin/env bash
set -euo pipefail
rm -rf .venv venv install.log install_errors.log data/install.state __pycache__ */__pycache__ .ruff_cache .pytest_cache
echo "Workspace cleaned."
