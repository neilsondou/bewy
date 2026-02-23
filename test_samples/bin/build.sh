#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
    
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
VERSION="${1:-dev}"

cleanup() {
    log_info "Cleaning up..."
    rm -rf "${BUILD_DIR}/tmp"
}
trap cleanup EXIT

build_project() {
    log_info "Building project v${VERSION}..."
    mkdir -p "${BUILD_DIR}/tmp"

    local src_files
    src_files=$(find "${PROJECT_DIR}/src" -name '*.c' -o -name '*.cpp' | wc -l)
    log_info "Found ${src_files} source files"

    for f in "${PROJECT_DIR}/src"/*.c; do
        [ -f "$f" ] || continue
        local name
        name=$(basename "$f" .c)
        log_info "Compiling ${name}..."
        gcc -O2 -Wall -o "${BUILD_DIR}/tmp/${name}" "$f"
    done

    log_info "Build complete!"
}

run_tests() {
    log_info "Running tests..."
    local passed=0
    local failed=0

    for test_file in "${PROJECT_DIR}/test"/*.sh; do
        [ -f "$test_file" ] || continue
        local test_name
        test_name=$(basename "$test_file" .sh)
        if bash "$test_file"; then
            log_info "PASS: ${test_name}"
            ((passed++))
        else
            log_error "FAIL: ${test_name}"
            ((failed++))
        fi
    done

    echo ""
    log_info "Results: ${passed} passed, ${failed} failed"
    [ "$failed" -eq 0 ]
}

# Main
build_project
run_tests
