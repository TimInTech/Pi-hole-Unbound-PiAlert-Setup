#!/bin/bash
# Pi-hole Security Suite - Comprehensive Health Check & Validation Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Helper functions
log_test() {
    ((TESTS_TOTAL++))
    echo -e "${BLUE}[TEST $TESTS_TOTAL]${NC} $1"
}

log_pass() {
    ((TESTS_PASSED++))
    echo -e "${GREEN}  ✅ PASS:${NC} $1"
}

log_fail() {
    ((TESTS_FAILED++))
    echo -e "${RED}  ❌ FAIL:${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}  ⚠️  WARN:${NC} $1"
}

log_info() {
    echo -e "${BLUE}  ℹ️  INFO:${NC} $1"
}

echo "🔍 Pi-hole Security Suite - Comprehensive Health Check"
echo "======================================================"

# 1. Bash Syntax Check
log_test "Bash syntax validation"
if bash -n install.sh >/dev/null 2>&1; then
    log_pass "install.sh syntax is valid"
else
    log_fail "install.sh has syntax errors"
fi

if bash -n cleanup.sh >/dev/null 2>&1; then
    log_pass "cleanup.sh syntax is valid"
else
    log_fail "cleanup.sh has syntax errors"
fi

# 2. Python Environment Check
log_test "Python environment validation"
if [[ -f requirements.txt ]]; then
    log_pass "requirements.txt exists"
    
    # Check if virtual environment exists
    if [[ -d venv ]]; then
        log_pass "Virtual environment exists"
        
        # Check if all requirements are installed
        if ./venv/bin/pip check >/dev/null 2>&1; then
            log_pass "All Python dependencies are satisfied"
        else
            log_fail "Python dependency conflicts detected"
        fi
    else
        log_warn "Virtual environment not found (run install.sh first)"
    fi
else
    log_fail "requirements.txt missing"
fi

# 3. Python Code Quality
log_test "Python code quality (if ruff available)"
if command -v ruff >/dev/null 2>&1; then
    if ruff check . --quiet 2>/dev/null; then
        log_pass "No ruff linting issues found"
    else
        log_warn "Ruff linting issues detected (run: ruff check . --fix)"
    fi
else
    log_info "Ruff not installed, skipping code quality check"
fi

# 4. Python Import Tests
log_test "Python module import validation"
if [[ -f start_suite.py ]]; then
    if python3 -c "import sys; sys.path.append('.'); import start_suite" 2>/dev/null; then
        log_pass "start_suite.py imports successfully"
    else
        log_fail "start_suite.py import failed"
    fi
else
    log_fail "start_suite.py missing"
fi

# 5. Test Suite Execution
log_test "Running pytest test suite"
if [[ -d tests ]]; then
    if command -v pytest >/dev/null 2>&1; then
        if python3 -m pytest tests/ -v --tb=short 2>/dev/null; then
            log_pass "All tests passed"
        else
            log_fail "Some tests failed"
        fi
    else
        if [[ -f venv/bin/pytest ]]; then
            if ./venv/bin/python -m pytest tests/ -v --tb=short 2>/dev/null; then
                log_pass "All tests passed (venv)"
            else
                log_fail "Some tests failed (venv)"
            fi
        else
            log_warn "pytest not available"
        fi
    fi
else
    log_fail "tests/ directory missing"
fi

# 6. Service Status Checks (if installed)
log_test "System service status (if installed)"
services=("unbound" "pihole-FTL" "pihole-suite")
for service in "${services[@]}"; do
    if systemctl list-units --type=service | grep -q "$service"; then
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_pass "$service is active"
        else
            log_fail "$service is inactive"
        fi
    else
        log_info "$service not installed/configured"
    fi
done

# 7. Docker Container Checks (if installed)
log_test "Docker container status (if installed)"
if command -v docker >/dev/null 2>&1; then
    containers=("pihole" "netalertx")
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "$container"; then
            if docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
                log_pass "$container container is running"
            else
                log_fail "$container container is not running"
            fi
        else
            log_info "$container container not found"
        fi
    done
else
    log_info "Docker not installed"
fi

# 8. DNS Resolution Tests (if services are running)
log_test "DNS resolution functionality"
if systemctl is-active --quiet unbound 2>/dev/null; then
    if dig +short @127.0.0.1 -p 5335 example.com 2>/dev/null | grep -qE '^[0-9.]+$'; then
        log_pass "Unbound DNS resolution working"
    else
        log_fail "Unbound DNS resolution failed"
    fi
else
    log_info "Unbound not running, skipping DNS test"
fi

if systemctl is-active --quiet pihole-FTL 2>/dev/null || docker ps | grep -q pihole; then
    if dig +short @127.0.0.1 google.com 2>/dev/null | grep -qE '^[0-9.]+$'; then
        log_pass "Pi-hole DNS resolution working"
    else
        log_fail "Pi-hole DNS resolution failed"
    fi
else
    log_info "Pi-hole not running, skipping DNS test"
fi

# 9. API Endpoint Tests (if running)
log_test "API endpoint accessibility"
if [[ -f .env ]]; then
    source .env
    if curl -s http://127.0.0.1:${SUITE_PORT:-8090}/health >/dev/null 2>&1; then
        log_pass "Python API health endpoint accessible"
        
        if [[ -n "$SUITE_API_KEY" ]]; then
            if curl -s -H "X-API-Key: $SUITE_API_KEY" http://127.0.0.1:${SUITE_PORT:-8090}/info >/dev/null 2>&1; then
                log_pass "Python API info endpoint accessible with API key"
            else
                log_fail "Python API info endpoint not accessible"
            fi
        else
            log_warn "No API key configured"
        fi
    else
        log_info "Python API not running"
    fi
else
    log_info ".env file not found, skipping API tests"
fi

# 10. File Structure Validation
log_test "Required file structure validation"
required_files=("install.sh" "start_suite.py" "requirements.txt" "__init__.py")
for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        log_pass "$file exists"
    else
        log_fail "$file missing"
    fi
done

required_dirs=("tests" "data")
for dir in "${required_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        log_pass "$dir/ directory exists"
    else
        log_fail "$dir/ directory missing"
    fi
done

# 11. Configuration File Validation
log_test "Configuration file validation"
if [[ -f /etc/unbound/unbound.conf.d/forward.conf ]]; then
    if grep -q "forward-tls-upstream: yes" /etc/unbound/unbound.conf.d/forward.conf; then
        log_pass "Unbound DoT configuration found"
    else
        log_warn "Unbound DoT configuration incomplete"
    fi
else
    log_info "Unbound configuration not found (not installed)"
fi

# Summary
echo ""
echo "======================================================"
echo "🏁 Test Summary"
echo "======================================================"
echo -e "${BLUE}Total Tests:${NC} $TESTS_TOTAL"
echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "${RED}Failed:${NC} $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}🎉 All tests passed! System is healthy.${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some tests failed. Check the output above.${NC}"
    exit 1
fi
