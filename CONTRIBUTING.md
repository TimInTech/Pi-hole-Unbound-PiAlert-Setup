# Contributing to Pi-hole-Unbound-PiAlert-Setup

First off, thank you for considering contributing to this project! It's people like you that make this setup better for everyone.

## How Can I Contribute?

### Reporting Bugs
If you find a bug, please create an issue on GitHub. Before creating a new issue, please check if a similar issue already exists.

When you create an issue, please include:
* A clear and descriptive title.
* Steps to reproduce the problem.
* What you expected to happen vs what actually happened.
* Relevant logs (use the Rescue Menu `sudo pihole-rescue` to gather system status).
* Information about your system (OS version, Raspberry Pi model).

### Suggesting Enhancements
Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please provide:
* A clear and descriptive title.
* A step-by-step description of the suggested enhancement.
* Specific examples to demonstrate the steps.
* The rationale for why this enhancement would be useful.

### Pull Requests
1. Fork the repository and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. Ensure the test suite passes (run `bash scripts/nightly_test.sh` if applicable).
4. Update the documentation if your changes require it.
5. Make sure your code follows the existing style (run `shellcheck` on bash scripts).
6. Issue that pull request!

## Development Setup
If you want to contribute to the codebase:
1. Clone your fork locally.
2. We highly recommend using a test environment (e.g. a Proxmox VM or a dedicated testing Raspberry Pi) instead of your production DNS server to avoid network downtime.
3. For Python changes in the `start_suite.py`, set up a virtual environment and use `pylint` for formatting checks.

Thank you for your contributions!
