#!/bin/bash

echo "🔍 Finding ALL Missing Tests"
echo "============================"
echo ""

# Get all executed tests from the last run
echo "📋 Extracting all executed tests..."
grep "Test case '" /tmp/test_execution_detail.log 2>/dev/null | sed "s/.*Test case '\([^.]*\)\.\([^(]*\).*/\1:\2/" | sort | uniq > /tmp/all_executed.txt

# Function to check tests for a specific file
check_tests_for_file() {
    local file=$1
    local class_name=$(basename "$file" .swift)
    local execution_name=$class_name
    
    # Handle special case for CoinManagerTests
    if [[ "$class_name" == "CoinManagerTests" ]]; then
        execution_name="CoinManagerParameterMappingTests"
    fi
    
    # Get all tests from source
    grep "func test" "$file" | sed 's/.*func \(test[^(]*\).*/\1/' | sort > /tmp/${class_name}_source.txt
    
    # Get executed tests for this class
    grep "^${execution_name}:" /tmp/all_executed.txt | cut -d: -f2 | sort > /tmp/${class_name}_executed.txt
    
    # Find missing tests
    local missing=$(comm -23 /tmp/${class_name}_source.txt /tmp/${class_name}_executed.txt)
    
    if [ ! -z "$missing" ]; then
        echo "❌ $class_name:"
        echo "$missing" | sed 's/^/   - /'
        echo ""
    fi
}

# Check all test files
echo "📊 Checking each test class for missing tests..."
echo ""

total_missing=0

for file in $(find CryptoAppTests -name "*Tests.swift" | sort); do
    check_tests_for_file "$file"
done

echo "📋 Summary of ALL missing tests:"
echo ""

# Count total missing
for file in $(find CryptoAppTests -name "*Tests.swift" | sort); do
    class_name=$(basename "$file" .swift)
    execution_name=$class_name
    
    if [[ "$class_name" == "CoinManagerTests" ]]; then
        execution_name="CoinManagerParameterMappingTests"
    fi
    
    grep "func test" "$file" | sed 's/.*func \(test[^(]*\).*/\1/' | sort > /tmp/${class_name}_source.txt
    grep "^${execution_name}:" /tmp/all_executed.txt | cut -d: -f2 | sort > /tmp/${class_name}_executed.txt
    missing=$(comm -23 /tmp/${class_name}_source.txt /tmp/${class_name}_executed.txt)
    
    if [ ! -z "$missing" ]; then
        while IFS= read -r test; do
            echo "  - $class_name.$test"
            ((total_missing++))
        done <<< "$missing"
    fi
done

echo ""
echo "Total missing tests: $total_missing"
