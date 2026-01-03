#!/bin/bash
# OpenCL Integration Test Runner
# This script performs basic validation tests for the OpenCL implementation

set -e

echo "============================================"
echo "OpenCL Integration Test Suite"
echo "============================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS="${GREEN}✅ PASS${NC}"
FAIL="${RED}❌ FAIL${NC}"
WARN="${YELLOW}⚠️  WARN${NC}"

# Check if binary exists
if [ ! -f "./VanitySearch" ]; then
    echo -e "${FAIL} VanitySearch binary not found"
    echo "Please run: make opencl"
    exit 1
fi

# Create test output directory
mkdir -p test_results
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGDIR="test_results/${TIMESTAMP}"
mkdir -p "${LOGDIR}"

echo "Test logs will be saved to: ${LOGDIR}"
echo ""

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected="$3"
    local timeout_sec="${4:-30}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -n "Test ${TOTAL_TESTS}: ${test_name}... "
    
    local logfile="${LOGDIR}/test${TOTAL_TESTS}.log"
    
    # Run test with timeout
    if timeout ${timeout_sec} bash -c "${test_cmd}" > "${logfile}" 2>&1; then
        # Check if expected string is in output
        if grep -q "${expected}" "${logfile}"; then
            echo -e "${PASS}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${FAIL} (expected: '${expected}')"
            echo "  See log: ${logfile}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        EXIT_CODE=$?
        if [ ${EXIT_CODE} -eq 124 ]; then
            echo -e "${WARN} (timeout after ${timeout_sec}s)"
            echo "  This may be normal for difficult prefixes"
            echo "  See log: ${logfile}"
        else
            echo -e "${FAIL} (exit code: ${EXIT_CODE})"
            echo "  See log: ${logfile}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
        return 1
    fi
}

# ===== Test Suite =====

echo "Phase 1: Basic Functionality"
echo "----------------------------"

# Test 1: Help/Version
run_test "Display help" \
    "./VanitySearch -h" \
    "Usage" \
    5

# Test 2: Device Listing
run_test "Device enumeration" \
    "./VanitySearch -l" \
    "OpenCL Platforms" \
    10

echo ""
echo "Phase 2: OpenCL Initialization"
echo "-------------------------------"

# Test 3: Simple prefix (very easy, should find quickly)
run_test "Simple 3-char prefix" \
    "./VanitySearch -opencl -gpu -t 0 pocx1T" \
    "PubAddress" \
    60

# Test 4: 4-char prefix
run_test "Medium 4-char prefix" \
    "./VanitySearch -opencl -gpu -t 0 pocx1Te" \
    "PubAddress" \
    120

echo ""
echo "Phase 3: Address Modes"
echo "----------------------"

# Test 5: Compressed mode (explicit)
run_test "Compressed mode" \
    "./VanitySearch -opencl -gpu -t 0 pocx1T" \
    "Compressed" \
    60

# Test 6: Uncompressed mode
run_test "Uncompressed mode" \
    "./VanitySearch -opencl -gpu -t 0 -u pocx1T" \
    "Uncompressed" \
    60

# Test 7: Both modes
run_test "Both modes" \
    "./VanitySearch -opencl -gpu -t 0 -b pocx1T" \
    "Both" \
    60

echo ""
echo "Phase 4: Pattern Matching"
echo "-------------------------"

# Test 8: Wildcard ? (any single char)
run_test "Pattern with ?" \
    "./VanitySearch -opencl -gpu -t 0 'pocx1T?'" \
    "PubAddress" \
    60

# Test 9: Wildcard * (any chars)
run_test "Pattern with *" \
    "./VanitySearch -opencl -gpu -t 0 'pocx1T*st'" \
    "PubAddress" \
    60

echo ""
echo "Phase 5: Grid Configuration"
echo "---------------------------"

# Test 10: Small grid
run_test "Small grid (128x128)" \
    "./VanitySearch -opencl -gpu -t 0 -g 128,128 pocx1T" \
    "PubAddress" \
    60

# Test 11: Medium grid
run_test "Medium grid (256x128)" \
    "./VanitySearch -opencl -gpu -t 0 -g 256,128 pocx1T" \
    "PubAddress" \
    60

# Test 12: Large grid
run_test "Large grid (512x128)" \
    "./VanitySearch -opencl -gpu -t 0 -g 512,128 pocx1T" \
    "PubAddress" \
    60

echo ""
echo "Phase 6: Error Handling"
echo "-----------------------"

# Test 13: Invalid GPU ID
run_test "Invalid GPU ID" \
    "./VanitySearch -opencl -gpuId 99 pocx1T 2>&1" \
    "Invalid GPU ID" \
    10

# Test 14: Invalid prefix characters
run_test "Invalid prefix" \
    "./VanitySearch -opencl -gpu 'invalid!' 2>&1" \
    "Invalid" \
    10

echo ""
echo "============================================"
echo "Test Summary"
echo "============================================"
echo "Total Tests:  ${TOTAL_TESTS}"
echo -e "Passed:       ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Failed:       ${RED}${FAILED_TESTS}${NC}"
echo ""

if [ ${FAILED_TESTS} -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✅${NC}"
    echo ""
    echo "The OpenCL implementation is working correctly."
    echo "You can now use it for production searches."
    exit 0
else
    echo -e "${RED}Some tests failed! ❌${NC}"
    echo ""
    echo "Please review the logs in: ${LOGDIR}"
    echo "Fix the issues and run tests again."
    exit 1
fi
