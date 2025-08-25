#!/bin/bash

# Test Coverage Generation Script with Embedded HTML Report
# This version embeds the JSON data directly in the HTML to avoid CORS issues

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="CryptoApp"
SCHEME_NAME="CryptoApp"
WORKSPACE_FILE="CryptoApp.xcworkspace"
PROJECT_FILE="CryptoApp.xcodeproj"

# Directories
PROJECT_DIR="$(pwd)"
COVERAGE_DIR="$PROJECT_DIR/coverage_reports"
HTML_DIR="$COVERAGE_DIR/html"
DETAILED_HTML_DIR="$COVERAGE_DIR/detailed_html"
DERIVED_DATA_DIR="$PROJECT_DIR/DerivedData"

# Build settings
DESTINATION="platform=iOS Simulator,name=iPhone 16 Pro Max,OS=latest"

echo -e "${BLUE}🧪 CryptoApp Test Coverage Generator (Embedded Version)${NC}"
echo "=================================================="

# Check if running from project root
if [ ! -d "$PROJECT_FILE" ] && [ ! -d "$WORKSPACE_FILE" ]; then
    echo -e "${RED}❌ Error: Must run from project root directory${NC}"
    exit 1
fi

# Determine whether to use workspace or project
if [ -d "$WORKSPACE_FILE" ]; then
    BUILD_FILE="-workspace $WORKSPACE_FILE"
    echo -e "${GREEN}✅ Using workspace: $WORKSPACE_FILE${NC}"
else
    BUILD_FILE="-project $PROJECT_FILE"
    echo -e "${GREEN}✅ Using project: $PROJECT_FILE${NC}"
fi

# Create directories
echo -e "${YELLOW}📁 Creating coverage directories...${NC}"
mkdir -p "$COVERAGE_DIR"
mkdir -p "$HTML_DIR"
mkdir -p "$DETAILED_HTML_DIR"

# Clean previous coverage data
echo -e "${YELLOW}🧹 Cleaning previous coverage data...${NC}"
rm -rf "$COVERAGE_DIR"/*.json
rm -rf "$COVERAGE_DIR"/*.txt
rm -rf "$HTML_DIR"/*
rm -rf "$DETAILED_HTML_DIR"/*

# Clean DerivedData
echo -e "${YELLOW}🧹 Cleaning DerivedData...${NC}"
rm -rf "$DERIVED_DATA_DIR"

# Run tests with coverage
echo -e "${YELLOW}🏃‍♂️ Running tests with coverage...${NC}"

# Check if xcpretty is available for prettier output
if command -v xcpretty &> /dev/null; then
    xcodebuild test \
        $BUILD_FILE \
        -scheme "$SCHEME_NAME" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        -enableCodeCoverage YES \
        -parallel-testing-enabled NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        | tee /tmp/latest_test_output.log | xcpretty --color
else
    xcodebuild test \
        $BUILD_FILE \
        -scheme "$SCHEME_NAME" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        -enableCodeCoverage YES \
        -parallel-testing-enabled NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        | tee /tmp/latest_test_output.log
fi

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}❌ Tests failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Tests completed successfully!${NC}"

# Find the coverage data
echo -e "${YELLOW}🔍 Locating coverage data...${NC}"
COVERAGE_DATA_DIR=$(find "$DERIVED_DATA_DIR" -name "*.xcresult" | head -1)

if [ -z "$COVERAGE_DATA_DIR" ]; then
    # Fallback to checking logs directory
    COVERAGE_DATA_DIR=$(find "$DERIVED_DATA_DIR/Logs" -name "*.xcresult" 2>/dev/null | head -1)
fi

if [ -z "$COVERAGE_DATA_DIR" ]; then
    echo -e "${RED}❌ No coverage data found!${NC}"
    echo "Checked locations:"
    echo "  - $DERIVED_DATA_DIR"
    echo "  - $DERIVED_DATA_DIR/Logs"
    exit 1
fi

echo -e "${GREEN}✅ Found coverage data: $COVERAGE_DATA_DIR${NC}"

# Generate JSON coverage report
echo -e "${YELLOW}📋 Generating JSON coverage report...${NC}"
xcrun xccov view --report --json "$COVERAGE_DATA_DIR" > "$COVERAGE_DIR/coverage_raw.json"

# Clean up the JSON file
echo -e "${YELLOW}🧹 Cleaning JSON data...${NC}"
python3 - <<'EOF' "$COVERAGE_DIR/coverage_raw.json" "$COVERAGE_DIR/coverage.json"
import json
import sys

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file, 'r') as f:
    content = f.read().strip().rstrip('%').strip()

# Parse and reformat JSON to ensure it's valid
data = json.loads(content)

with open(output_file, 'w') as f:
    json.dump(data, f, indent=2)

print("✅ JSON coverage report cleaned and validated successfully")
EOF

# Remove the raw file
rm -f "$COVERAGE_DIR/coverage_raw.json"

# Generate simple text summary
echo -e "${YELLOW}📋 Generating text summary...${NC}"
xcrun xccov view --report "$COVERAGE_DATA_DIR" > "$HTML_DIR/coverage_summary.txt"

# Calculate test counts
echo -e "${YELLOW}📊 Calculating test statistics...${NC}"

# Count total tests in source code
TOTAL_TESTS=0
for file in $(find CryptoAppTests -name "*Tests.swift" 2>/dev/null); do
    count=$(grep -c "func test" "$file" 2>/dev/null || echo 0)
    TOTAL_TESTS=$((TOTAL_TESTS + count))
done

# Count executed tests from latest test output
EXECUTED_TESTS=0
if [ -f "/tmp/latest_test_output.log" ]; then
    EXECUTED_TESTS=$(grep -c "Test Case.*passed" /tmp/latest_test_output.log 2>/dev/null | tr -d '\n' || echo 0)
fi

# If no executed tests found, try alternative methods
if [ "$EXECUTED_TESTS" -eq 0 ] && [ -f "$HTML_DIR/coverage_summary.txt" ]; then
    EXECUTED_TESTS=$(grep -c "Test Case.*passed" "$HTML_DIR/coverage_summary.txt" 2>/dev/null | tr -d '\n' || echo 0)
fi

# Clean up the numbers (remove any whitespace/newlines)
EXECUTED_TESTS=$(echo "$EXECUTED_TESTS" | tr -d ' \n\r')
TOTAL_TESTS=$(echo "$TOTAL_TESTS" | tr -d ' \n\r')

echo -e "${GREEN}📊 Test Statistics:${NC}"
echo "  Total tests in source: $TOTAL_TESTS"
echo "  Tests executed: $EXECUTED_TESTS"
echo "  Missing tests: $((TOTAL_TESTS - EXECUTED_TESTS))"

# Generate HTML report with embedded JSON data
echo -e "${YELLOW}🌐 Generating embedded HTML coverage report...${NC}"
python3 - <<EOF "$COVERAGE_DIR/coverage.json" "$HTML_DIR/index.html" "$EXECUTED_TESTS" "$TOTAL_TESTS"
import json
import sys
from datetime import datetime

json_file = sys.argv[1]
html_file = sys.argv[2]
executed_tests = sys.argv[3]
total_tests = sys.argv[4]

# Read the JSON data
with open(json_file, 'r') as f:
    coverage_data = json.load(f)

# Filter out UI files from the coverage data
def should_exclude_file(filename):
    name = filename.lower()
    return (name.endswith('viewcontroller.swift') or 
            name.endswith('vc.swift') or
            'appdelegate' in name or 
            'scenedelegate' in name or
            'storyboard' in name or
            name.endswith('view.swift') or
            name.endswith('cell.swift') or
            'tableview' in name or
            'collectionview' in name or
            name.endswith('.m') or  # Exclude Objective-C implementation files
            name.endswith('.h') or  # Exclude Objective-C header files
            'mock' in name or       # Exclude mock services and test utilities
            'stub' in name or       # Exclude stub implementations
            'fake' in name or       # Exclude fake implementations
            'marker' in name or     # Exclude chart markers (UI components)
            'button' in name or     # Exclude UI buttons
            'skeleton' in name or   # Exclude skeleton loading views
            'balloon' in name or    # Exclude balloon markers
            'icon' in name or       # Exclude icon generators
            'theme' in name or      # Exclude theme/styling files
            'chartdatacache.swift' in name or  # Exclude simple cache struct from coverage
            'statitem' in name)     # Exclude simple UI model structs

# Filter the coverage data to exclude UI files
for target in coverage_data.get('targets', []):
    if target.get('files'):
        # Filter out UI files
        original_files = target['files']
        filtered_files = [f for f in original_files if not should_exclude_file(f.get('name', ''))]
        target['files'] = filtered_files
        
        # Recalculate target totals based on filtered files
        total_executable = sum(f.get('executableLines', 0) for f in filtered_files)
        total_covered = sum(f.get('coveredLines', 0) for f in filtered_files)
        
        target['executableLines'] = total_executable
        target['coveredLines'] = total_covered
        target['lineCoverage'] = total_covered / total_executable if total_executable > 0 else 0

# Also update root level totals - only count app target, not test targets
app_target = next((t for t in coverage_data.get('targets', []) if 'CryptoApp.app' in t.get('buildProductPath', '')), None)
if app_target:
    root_executable = app_target.get('executableLines', 0)
    root_covered = app_target.get('coveredLines', 0)
else:
    # Fallback: sum all targets if app target not found
    all_files = []
    for target in coverage_data.get('targets', []):
        all_files.extend(target.get('files', []))
    root_executable = sum(f.get('executableLines', 0) for f in all_files)
    root_covered = sum(f.get('coveredLines', 0) for f in all_files)

coverage_data['executableLines'] = root_executable
coverage_data['coveredLines'] = root_covered
coverage_data['lineCoverage'] = root_covered / root_executable if root_executable > 0 else 0

# Generate the HTML with embedded data
html_content = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CryptoApp Test Coverage Report</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #000000;
            min-height: 100vh;
            padding: 2rem;
            color: #ffffff;
        }}
        
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background: #000000 !important;
            border-radius: 16px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
            overflow: hidden;
            border: 1px solid #333333;
        }}
        
        .header {{
            text-align: center;
            background: #000000 !important;
            padding: 3rem 2rem;
            border-bottom: 2px solid #BCFF2F;
            position: relative;
        }}
        
        .header::before {{
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: linear-gradient(45deg, transparent 30%, rgba(188, 255, 47, 0.05) 50%, transparent 70%);
            animation: shimmer 3s ease-in-out infinite;
        }}
        
        @keyframes shimmer {{
            0%, 100% {{ opacity: 0; }}
            50% {{ opacity: 1; }}
        }}
        
        h1 {{
            font-size: 2.5rem;
            font-weight: 700;
            margin-bottom: 0.5rem;
            background: linear-gradient(135deg, #ffffff 0%, #BCFF2F 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            position: relative;
            z-index: 1;
        }}
        
        .subtitle {{
            color: #cccccc;
            font-size: 1.1rem;
            opacity: 0.8;
            position: relative;
            z-index: 1;
        }}
        
        .stats-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            padding: 2rem;
            background: #000000 !important;
        }}
        
        .stat-card {{
            background: #000000 !important;
            padding: 2rem;
            border-radius: 12px;
            text-align: center;
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
            transition: all 0.3s ease;
            border: 1px solid #333333;
            position: relative;
            overflow: hidden;
        }}
        
        .stat-card:hover {{
            transform: translateY(-5px);
            box-shadow: 0 16px 32px rgba(0, 0, 0, 0.6);
            border-color: #BCFF2F;
        }}
        
        .stat-card::before {{
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 2px;
            background: linear-gradient(90deg, transparent, #BCFF2F, transparent);
            transition: left 0.5s ease;
        }}
        
        .stat-card:hover::before {{
            left: 100%;
        }}
        
        .stat-value {{
            font-size: 2.5rem;
            font-weight: 800;
            color: #BCFF2F;
            margin-bottom: 0.5rem;
            text-shadow: 0 0 20px rgba(188, 255, 47, 0.3);
        }}
        
        /* Remove red styling from overall coverage */
        .stat-value.poor {{
            color: #FF4444 !important;
            background: transparent !important;
            border: none !important;
            padding: 0 !important;
            text-shadow: 0 0 20px rgba(255, 68, 68, 0.3) !important;
        }}
        
        .stat-label {{
            color: #cccccc;
            text-transform: uppercase;
            font-size: 0.875rem;
            letter-spacing: 1px;
            font-weight: 600;
        }}
        
        .file-section {{
            margin-top: 2rem;
            padding: 2rem;
            background: #000000 !important;
        }}
        
        .file-header {{
            font-size: 1.5rem;
            color: #ffffff;
            margin-bottom: 2rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
            padding-left: 1rem;
            border-left: 4px solid #BCFF2F;
        }}
        
        .file-table {{
            width: 100%;
            border-collapse: collapse;
            background: #000000 !important;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
            border: 1px solid #333333;
        }}
        
        .file-table th {{
            background: linear-gradient(135deg, #1A1A1A 0%, #000000 100%);
            padding: 1rem;
            text-align: left;
            font-weight: 600;
            color: #BCFF2F;
            border-bottom: 1px solid #BCFF2F;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            font-size: 0.9rem;
        }}
        
        .file-table td {{
            padding: 1rem;
            border-bottom: 1px solid #333333;
            color: #ffffff;
        }}
        
        .file-table tr:hover {{
            background: #0D0D0D;
        }}
        
        .file-table tr:hover td:first-child {{
            border-left: 4px solid #BCFF2F;
            padding-left: calc(1rem - 4px);
        }}
        
        .file-name {{
            font-family: 'SF Mono', 'Monaco', 'Inconsolata', 'Roboto Mono', monospace;
            font-size: 0.9rem;
            color: #ffffff;
            font-weight: 600;
        }}
        
        .coverage-bar {{
            width: 100%;
            height: 14px;
            background: #000000 !important;
            border-radius: 7px;
            overflow: hidden;
            margin-top: 0.25rem;
            box-shadow: none;
            border: 1px solid #555555;
        }}
        
        .coverage-fill {{
            height: 100%;
            transition: width 0.3s ease;
            position: relative;
            opacity: 1 !important;
        }}
        
        .coverage-fill::after {{
            display: none;
            content: none;
        }}
        
        @keyframes shine {{
            0% {{ left: -100%; }}
            100% {{ left: 100%; }}
        }}
        
        .coverage-percent {{
            font-weight: 700;
            color: #ffffff;
            padding: 0.3rem 0.8rem;
            border-radius: 20px;
            text-align: center;
            min-width: 60px;
            border: 1px solid currentColor;
            display: inline-block;
        }}
        
                .good {{ 
            color: #BCFF2F;
            background: transparent;
            border: none;
        }}
        .coverage-fill.good {{ 
            background: linear-gradient(90deg, #BCFF2F 0%, #9FE82A 100%) !important;
            box-shadow: 0 0 8px rgba(188, 255, 47, 0.35) !important;
            border: 1px solid rgba(188, 255, 47, 0.6) !important;
        }}
        
        .medium {{ 
            color: #FFA500;
            background: transparent;
            border: none;
        }}
        .coverage-fill.medium {{ 
            background: linear-gradient(90deg, #FFA500 0%, #FF8C00 100%) !important;
            box-shadow: 0 0 8px rgba(255, 165, 0, 0.25) !important;
            border: 1px solid rgba(255, 165, 0, 0.5) !important;
        }}
        
        .poor {{ 
            color: #FF4444;
            background: transparent;
            border: none;
        }}
        .coverage-fill.poor {{ 
            background: linear-gradient(90deg, #FF5A5A 0%, #CC3A3A 100%) !important;
            box-shadow: 0 0 8px rgba(255, 90, 90, 0.25) !important;
            border: 1px solid rgba(255, 90, 90, 0.5) !important;
        }}
        
        .lines-covered {{
            font-size: 0.9rem;
            color: #ffffff !important;
            font-weight: 500;
        }}
        
        .tests-banner {{
            background: #000000 !important;
            color: #ffffff;
            text-align: center;
            margin: 2rem 0;
            padding: 1rem 0;
        }}
        

        
        .actions {{
            display: flex;
            gap: 1rem;
            justify-content: center;
            margin-top: 2rem;
            padding: 2rem;
            background: #000000;
            border-top: none;
        }}
        
        .btn {{
            padding: 0.8rem 1.5rem;
            background: linear-gradient(135deg, #BCFF2F, #9FE82A);
            color: #000000;
            text-decoration: none;
            border-radius: 25px;
            font-weight: 700;
            transition: all 0.3s ease;
            box-shadow: 0 5px 15px rgba(188, 255, 47, 0.3);
            border: 2px solid #BCFF2F;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
        
        .btn:hover {{
            transform: translateY(-2px);
            box-shadow: 0 10px 25px rgba(188, 255, 47, 0.5);
            background: #BCFF2F;
            border-color: #9FE82A;
            text-decoration: none;
            color: #000000;
        }}
        
        .timestamp {{
            text-align: center;
            color: #cccccc;
            margin-top: 2rem;
            font-size: 0.875rem;
            padding: 1rem;
        }}

        .error {{
            background: rgba(255, 68, 68, 0.1);
            border: 1px solid #FF4444;
            color: #FF4444;
            padding: 1rem;
            border-radius: 8px;
            margin: 1rem 0;
        }}
        
        @media (max-width: 768px) {{
            .stats-grid {{
                grid-template-columns: 1fr;
                gap: 1rem;
            }}
            
            .file-table {{
                font-size: 0.8rem;
            }}
            
            .stat-value {{
                font-size: 2rem;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛡️ Test Coverage Report</h1>
            <p class="subtitle">CryptoApp iOS Application (Core Logic Only)</p>
        </div>
        
        <div class="stats-grid" id="statsGrid">
            <div class="stat-card">
                <div class="stat-value" id="overallCoverage">--</div>
                <div class="stat-label">Overall Coverage</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="linesCovered">--</div>
                <div class="stat-label">Lines Covered</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="totalLines">--</div>
                <div class="stat-label">Total Lines</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="filesTested">--</div>
                <div class="stat-label">Files With Coverage</div>
            </div>
        </div>
        
        <div class="tests-banner">
            <p style="font-size: 1.1rem;">✅ <strong>{executed_tests} tests</strong> executed successfully out of <strong>{total_tests} total tests</strong></p>
        </div>
        
        <div class="file-section">
            <h2 class="file-header">📁 File Coverage Details</h2>
            <div id="fileDetails"></div>
        </div>
        
        <div class="actions">
            <a href="../coverage.json" class="btn" download> View JSON Report</a>
            <a href="coverage_summary.txt" class="btn" download> View Summary</a>
        </div>
        
        <div class="timestamp">
            Generated on {datetime.now().strftime('%d/%m/%Y, %H:%M:%S')}
        </div>
    </div>
    
    <script>
        // Embedded coverage data
        const coverageData = {json.dumps(coverage_data)};
        
        function getCoverageClass(percentage) {{
            if (percentage >= 80) return 'good';
            if (percentage >= 60) return 'medium';
            return 'poor';
        }}
        
        function populateCoverageData(data) {{
            // Find the main app target (not test files)
            const appTarget = data.targets.find(target => 
                target.name === "CryptoApp.app" || 
                (target.name.includes("CryptoApp") && !target.name.includes("Test"))
            ) || data.targets[0];
            
            if (!appTarget) {{
                document.getElementById('fileDetails').innerHTML = 
                    '<div class="error">No coverage data found for app target</div>';
                return;
            }}
            
            // Calculate stats from important files only (exclude VCs, delegates, views)
            let totalLines = 0;
            let coveredLines = 0;
            let fileCount = 0;
            
            if (appTarget.files) {{
                appTarget.files
                    .filter(file => file.name && !file.name.includes('Test'))
                    .filter(file => {{
                        const name = file.name.toLowerCase();
                        // Exclude UI components, Objective-C files, and test utilities
                        return !name.includes('viewcontroller') && 
                               !name.includes('vc.swift') &&
                               !name.includes('appdelegate') && 
                               !name.includes('scenedelegate') &&
                               !name.includes('storyboard') &&
                               !name.includes('view.swift') &&
                               !name.includes('cell.swift') &&
                               !name.includes('tableview') &&
                               !name.includes('collectionview') &&
                               !name.endsWith('.m') &&      // Exclude Objective-C
                               !name.endsWith('.h') &&      // Exclude Objective-C headers
                               !name.includes('mock') &&    // Exclude mock services
                               !name.includes('stub') &&    // Exclude stub implementations
                               !name.includes('fake') &&    // Exclude fake implementations
                               !name.includes('marker') &&  // Exclude chart markers
                               !name.includes('button') &&  // Exclude UI buttons
                               !name.includes('skeleton') && // Exclude skeleton views
                               !name.includes('balloon') && // Exclude balloon markers
                               !name.includes('icon') &&    // Exclude icon generators
                               !name.includes('theme') &&   // Exclude theme files
                               !name.includes('statitem');
                    }})
                    .forEach(file => {{
                        totalLines += file.executableLines || 0;
                        coveredLines += file.coveredLines || 0;
                        fileCount++;
                    }});
            }}
            
            // Use the same calculation method as the terminal output for consistency
            const overallCoverage = totalLines > 0 ? 
                Math.round((coveredLines / totalLines) * 10000) / 100 : 0;
            
            // Update stats
            document.getElementById('overallCoverage').textContent = overallCoverage + '%';
            document.getElementById('overallCoverage').className = 'stat-value ' + getCoverageClass(overallCoverage);
            document.getElementById('linesCovered').textContent = coveredLines.toLocaleString() + ' / ' + totalLines.toLocaleString();
            document.getElementById('totalLines').textContent = totalLines.toLocaleString();
            document.getElementById('filesTested').textContent = fileCount;
            
            // Generate file details
            generateFileDetails(data);
        }}
        
        function generateFileDetails(data) {{
            const detailsContainer = document.getElementById('fileDetails');
            let html = '';
            
            // Find the main app target
            const appTarget = data.targets.find(target => 
                target.name === "CryptoApp.app" || 
                (target.name.includes("CryptoApp") && !target.name.includes("Test"))
            ) || data.targets[0];
            
            if (!appTarget || !appTarget.files) {{
                detailsContainer.innerHTML = '<div class="error">No file details available</div>';
                return;
            }}
            
            const files = appTarget.files
                .filter(file => file.name && !file.name.includes('Test'))
                .filter(file => {{
                    const name = file.name.toLowerCase();
                    // Exclude UI components, Objective-C files, and test utilities
                    return !name.includes('viewcontroller') && 
                           !name.includes('vc.swift') &&
                           !name.includes('appdelegate') && 
                           !name.includes('scenedelegate') &&
                           !name.includes('storyboard') &&
                           !name.includes('view.swift') &&
                           !name.includes('cell.swift') &&
                           !name.includes('tableview') &&
                           !name.includes('collectionview') &&
                           !name.endsWith('.m') &&      // Exclude Objective-C
                           !name.endsWith('.h') &&      // Exclude Objective-C headers
                           !name.includes('mock') &&    // Exclude mock services
                           !name.includes('stub') &&    // Exclude stub implementations
                           !name.includes('fake') &&    // Exclude fake implementations
                           !name.includes('marker') &&  // Exclude chart markers
                           !name.includes('button') &&  // Exclude UI buttons
                           !name.includes('skeleton') && // Exclude skeleton views
                           !name.includes('balloon') && // Exclude balloon markers
                           !name.includes('icon') &&    // Exclude icon generators
                           !name.includes('theme') &&   // Exclude theme files
                           !name.includes('statitem');
                }})
                .sort((a, b) => {{
                    const aCoverage = a.lineCoverage || 0;
                    const bCoverage = b.lineCoverage || 0;
                    return bCoverage - aCoverage;
                }});
            
            html = '<table class="file-table">';
            html += '<thead><tr><th>File</th><th>Coverage</th><th>Lines</th></tr></thead>';
            html += '<tbody>';
            
            files.forEach(file => {{
                const coverage = Math.round((file.lineCoverage || 0) * 100);
                const coverageClass = getCoverageClass(coverage);
                const fileName = file.name.split('/').pop();
                
                html += '<tr>' +
                    '<td class="file-name">' + fileName + '</td>' +
                    '<td>' +
                        '<div class="coverage-percent ' + coverageClass + '">' + coverage + '%</div>' +
                        '<div class="coverage-bar">' +
                            '<div class="coverage-fill ' + coverageClass + '" style="width: ' + coverage + '%"></div>' +
                        '</div>' +
                    '</td>' +
                    '<td class="lines-covered">' + (file.coveredLines || 0) + ' / ' + (file.executableLines || 0) + '</td>' +
                '</tr>';
            }});
            
            html += '</tbody></table>';
            detailsContainer.innerHTML = html;
        }}
        
        // Initialize the page with embedded data
        populateCoverageData(coverageData);
    </script>
</body>
</html>'''

# Write the HTML file
with open(html_file, 'w') as f:
    f.write(html_content)

# Save the filtered JSON data as the main JSON file
# First, rename the original unfiltered file
import shutil
unfiltered_json_file = json_file.replace('.json', '_unfiltered.json')
shutil.move(json_file, unfiltered_json_file)

# Save the filtered data as the main JSON file
with open(json_file, 'w') as f:
    json.dump(coverage_data, f, indent=2)

# Also save a copy with the _filtered suffix for clarity
filtered_json_file = json_file.replace('.json', '_filtered.json')
with open(filtered_json_file, 'w') as f:
    json.dump(coverage_data, f, indent=2)

print("✅ Embedded HTML coverage report generated successfully")
print(f"✅ Main JSON report (filtered) saved as: {json_file}")
print(f"✅ Filtered JSON copy saved as: {filtered_json_file}")
print(f"✅ Unfiltered JSON backup saved as: {unfiltered_json_file}")

# Generate filtered text summary
app_target = next((t for t in coverage_data['targets'] if 'CryptoApp.app' in t.get('name', '')), None)
if app_target:
    summary_lines = []
    summary_lines.append("Filtered Coverage Report (Core Logic Only)")
    summary_lines.append("=" * 50)
    summary_lines.append(f"Overall: {app_target['lineCoverage']:.2%} ({app_target['coveredLines']}/{app_target['executableLines']})")
    summary_lines.append("")
    summary_lines.append("File Details:")
    summary_lines.append("-" * 50)
    
    for file in sorted(app_target.get('files', []), key=lambda f: f.get('lineCoverage', 0), reverse=True):
        name = file.get('name', '').split('/')[-1]
        coverage = file.get('lineCoverage', 0)
        covered = file.get('coveredLines', 0)
        total = file.get('executableLines', 0)
        summary_lines.append(f"{name:<40} {coverage:>6.1%} ({covered}/{total})")
    
    filtered_summary_file = html_file.replace('index.html', 'coverage_summary_filtered.txt')
    with open(filtered_summary_file, 'w') as f:
        f.write('\n'.join(summary_lines))
    
    print(f"✅ Filtered text summary saved as: {filtered_summary_file}")
EOF

echo -e "${GREEN}✅ Coverage reports generated successfully!${NC}"
echo ""
echo "📊 Coverage Reports:"
echo "  - HTML Report: $HTML_DIR/index.html"
echo "  - JSON Report: $COVERAGE_DIR/coverage.json"
echo "  - Text Summary: $HTML_DIR/coverage_summary.txt"
echo ""

# Open the HTML report in default browser
echo -e "${YELLOW}🌐 Opening coverage report in browser...${NC}"
open "$HTML_DIR/index.html"

echo -e "${GREEN}✨ Done!${NC}"
