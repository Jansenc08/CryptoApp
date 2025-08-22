#!/bin/bash

# Script to find which tests are not being executed

echo "🔍 Finding missing tests..."
echo "========================="

# Extract executed test names from the last test run
EXECUTED_TESTS_FILE="/tmp/executed_tests.txt"
ALL_TESTS_FILE="/tmp/all_tests.txt"
MISSING_TESTS_FILE="/tmp/missing_tests.txt"

# Find all test methods in the codebase
echo "📋 Finding all test methods..."
grep -r "func test" CryptoAppTests/ | grep -v "//" | sed 's/.*func \(test[^(]*\).*/\1/' | sort | uniq > "$ALL_TESTS_FILE"
TOTAL_TESTS=$(wc -l < "$ALL_TESTS_FILE" | tr -d ' ')
echo "Found $TOTAL_TESTS test methods"

# Find the most recent test log
LATEST_XCRESULT=$(find DerivedData/Logs/Test -name "*.xcresult" -type d | sort -r | head -1)

if [ -z "$LATEST_XCRESULT" ]; then
    echo "❌ No test results found. Run tests first."
    exit 1
fi

echo "📊 Analyzing test results from: $(basename "$LATEST_XCRESULT")"

# Extract executed tests from xcresult
xcrun xcresulttool get --path "$LATEST_XCRESULT" --format json 2>/dev/null | \
    grep -o '"identifier" : "[^"]*test[^"]*"' | \
    sed 's/.*"\(test[^"]*\)".*/\1/' | \
    grep -E "^test" | \
    sed 's/().*//' | \
    sort | uniq > "$EXECUTED_TESTS_FILE"

EXECUTED_COUNT=$(wc -l < "$EXECUTED_TESTS_FILE" | tr -d ' ')
echo "Found $EXECUTED_COUNT executed tests"

# Find missing tests
comm -23 "$ALL_TESTS_FILE" "$EXECUTED_TESTS_FILE" > "$MISSING_TESTS_FILE"
MISSING_COUNT=$(wc -l < "$MISSING_TESTS_FILE" | tr -d ' ')

echo ""
if [ "$MISSING_COUNT" -gt 0 ]; then
    echo "⚠️  Found $MISSING_COUNT tests that were NOT executed:"
    echo "================================================"
    
    # Show which file each missing test is in
    while IFS= read -r test_name; do
        FILE=$(grep -r "func $test_name" CryptoAppTests/ | head -1 | cut -d: -f1)
        echo "❌ $test_name"
        echo "   📁 $FILE"
        echo ""
    done < "$MISSING_TESTS_FILE"
else
    echo "✅ All tests were executed!"
fi

# Cleanup
rm -f "$EXECUTED_TESTS_FILE" "$ALL_TESTS_FILE" "$MISSING_TESTS_FILE"

echo ""
echo "Summary:"
echo "--------"
echo "Total test methods: $TOTAL_TESTS"
echo "Executed tests: $EXECUTED_COUNT"
echo "Missing tests: $MISSING_COUNT"
