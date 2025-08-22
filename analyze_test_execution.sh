#!/bin/bash

echo "🔍 Analyzing Test Execution in Detail"
echo "===================================="
echo ""

# Count tests per file
echo "📊 Test count per test class:"
echo ""

declare -A test_counts
declare -A executed_tests

# Get test counts from source files
while IFS= read -r file; do
    class_name=$(basename "$file" .swift)
    count=$(grep -c "func test" "$file" 2>/dev/null || echo 0)
    test_counts["$class_name"]=$count
    echo "  $class_name: $count tests"
done < <(find CryptoAppTests -name "*Tests.swift" | sort)

echo ""
echo "Total tests in code: $(IFS=+; echo "$((${test_counts[*]}))")"
echo ""

# Extract executed tests from the last test output
echo "📋 Analyzing last test execution..."
echo ""

# Count executed tests by test suite
last_output=$(tail -n 1000 /tmp/test_output.log 2>/dev/null || echo "")

if [ -z "$last_output" ]; then
    echo "⚠️  No recent test output found. Running a quick test to analyze..."
    echo ""
    
    # Run tests and capture output
    xcodebuild test \
        -scheme CryptoApp \
        -destination "platform=iOS Simulator,name=iPhone 16 Pro Max,OS=latest" \
        -only-testing:CryptoAppTests \
        2>&1 | tee /tmp/test_execution.log | \
        grep -E "Test (Suite|Case).*'.*'.*started|passed|failed" | \
        while read line; do
            echo "  $line"
        done
fi

echo ""
echo "🔍 Looking for patterns that might indicate skipped tests..."
echo ""

# Check for any test filtering in scheme
echo "1. Checking test scheme for filters:"
if [ -f "CryptoApp.xcodeproj/xcshareddata/xcschemes/CryptoApp.xcscheme" ]; then
    grep -i "skipped\|testable\|only-testing\|skip-testing" CryptoApp.xcodeproj/xcshareddata/xcschemes/CryptoApp.xcscheme || echo "  No test filters found in scheme"
fi

echo ""
echo "2. Checking for runtime test configuration:"
find . -name "*.xctestconfiguration" 2>/dev/null | head -5 || echo "  No test configuration files found"

echo ""
echo "3. Checking for test plan exclusions:"
if [ -f "CryptoAppTests.xctestplan" ]; then
    grep -i "skipped\|excluded" CryptoAppTests.xctestplan || echo "  No exclusions in test plan"
fi
