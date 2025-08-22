#!/bin/bash

# Test Coverage Generation Script for CryptoApp
# This script runs tests with coverage enabled and generates HTML reports

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

echo -e "${BLUE}🧪 CryptoApp Test Coverage Generator${NC}"
echo "=================================="

# Clean up previous coverage data
echo -e "${YELLOW}🧹 Cleaning previous coverage data...${NC}"
rm -rf "$COVERAGE_DIR"
mkdir -p "$HTML_DIR"
mkdir -p "$DETAILED_HTML_DIR"
rm -rf "$DERIVED_DATA_DIR"

# Determine if we should use workspace or project
BUILD_FILE=""
if [ -f "$WORKSPACE_FILE" ]; then
    BUILD_FILE="-workspace $WORKSPACE_FILE"
    echo -e "${GREEN}📁 Using workspace: $WORKSPACE_FILE${NC}"
else
    BUILD_FILE="-project $PROJECT_FILE"
    echo -e "${GREEN}📁 Using project: $PROJECT_FILE${NC}"
fi

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
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        | xcpretty --color
else
    echo -e "${YELLOW}⚠️  xcpretty not found, using raw output...${NC}"
    xcodebuild test \
        $BUILD_FILE \
        -scheme "$SCHEME_NAME" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        -enableCodeCoverage YES \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO
fi

# Check if tests passed
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}❌ Tests failed. Coverage report not generated.${NC}"
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

echo -e "${GREEN}📊 Found coverage data: $COVERAGE_DATA_DIR${NC}"

# Generate JSON coverage report
echo -e "${YELLOW}📋 Generating JSON coverage report...${NC}"
xcrun xccov view --report --json "$COVERAGE_DATA_DIR" > "$COVERAGE_DIR/coverage_raw.json"

# Clean up the JSON file (remove any trailing characters that might break parsing)
python3 -c "
import json
import sys

try:
    with open('$COVERAGE_DIR/coverage_raw.json', 'r') as f:
        content = f.read().strip()
        # Remove any trailing % or other characters
        content = content.rstrip('%').strip()
        
    # Parse and reformat JSON to ensure it's valid
    data = json.loads(content)
    
    with open('$COVERAGE_DIR/coverage.json', 'w') as f:
        json.dump(data, f, indent=2)
        
    print('✅ JSON coverage report cleaned and validated')
except Exception as e:
    print(f'❌ Error processing JSON: {e}')
    # Fallback: just copy the raw file
    import shutil
    shutil.copy('$COVERAGE_DIR/coverage_raw.json', '$COVERAGE_DIR/coverage.json')
" 2>/dev/null || {
    # Fallback if Python fails: use sed to remove trailing %
    sed 's/%$//' "$COVERAGE_DIR/coverage_raw.json" > "$COVERAGE_DIR/coverage.json"
}

# Remove the raw file
rm -f "$COVERAGE_DIR/coverage_raw.json"

# Copy JSON to HTML directory for easy access
cp "$COVERAGE_DIR/coverage.json" "$HTML_DIR/coverage.json"

# Generate simple HTML report using xccov
echo -e "${YELLOW}🌐 Generating HTML coverage report...${NC}"
xcrun xccov view --report "$COVERAGE_DATA_DIR" > "$HTML_DIR/coverage_summary.txt"

# Create a beautiful HTML report
cat > "$HTML_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CryptoApp - Test Coverage Report</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 16px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 10px;
            font-weight: 300;
        }
        
        .header p {
            opacity: 0.9;
            font-size: 1.1rem;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 30px;
        }
        
        .stat-card {
            background: #f8fafc;
            border-radius: 12px;
            padding: 25px;
            text-align: center;
            border-left: 4px solid #667eea;
            transition: transform 0.2s ease;
        }
        
        .stat-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(0,0,0,0.1);
        }
        
        .stat-value {
            font-size: 2.5rem;
            font-weight: bold;
            color: #2d3748;
            margin-bottom: 5px;
        }
        
        .stat-label {
            color: #718096;
            font-size: 0.9rem;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .coverage-bar {
            width: 100%;
            height: 8px;
            background: #e2e8f0;
            border-radius: 4px;
            margin: 10px 0;
            overflow: hidden;
        }
        
        .coverage-fill {
            height: 100%;
            background: linear-gradient(90deg, #48bb78, #38a169);
            transition: width 0.3s ease;
        }
        
        .details-section {
            padding: 30px;
            background: #f8fafc;
        }
        
        .details-section h2 {
            margin-bottom: 20px;
            color: #2d3748;
            font-size: 1.5rem;
        }
        
        .file-coverage {
            background: white;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 15px;
            border-left: 4px solid #e2e8f0;
        }
        
        .file-name {
            font-weight: 600;
            color: #2d3748;
            margin-bottom: 10px;
        }
        
        .actions {
            padding: 30px;
            text-align: center;
            background: white;
        }
        
        .btn {
            display: inline-block;
            padding: 12px 30px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            border-radius: 25px;
            margin: 0 10px;
            transition: transform 0.2s ease;
            font-weight: 500;
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(102, 126, 234, 0.3);
        }
        
        .timestamp {
            text-align: center;
            padding: 20px;
            color: #718096;
            font-size: 0.9rem;
            background: #f8fafc;
        }
        
        .high-coverage { border-left-color: #48bb78; }
        .medium-coverage { border-left-color: #ed8936; }
        .low-coverage { border-left-color: #f56565; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛡️ Test Coverage Report</h1>
            <p>CryptoApp iOS Application</p>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value" id="totalCoverage">--</div>
                <div class="stat-label">Overall Coverage</div>
                <div class="coverage-bar">
                    <div class="coverage-fill" id="overallBar" style="width: 0%"></div>
                </div>
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
                <div class="stat-value" id="filesCount">--</div>
                <div class="stat-label">Files Tested</div>
            </div>
        </div>
        
        <div class="details-section">
            <h2>📁 File Coverage Details</h2>
            <div id="fileDetails">
                <p>Loading coverage details...</p>
            </div>
        </div>
        
        <div class="actions">
            <a href="coverage.json" class="btn" download>📊 Download JSON Report</a>
            <a href="coverage_summary.txt" class="btn" download>📋 Download Summary</a>
        </div>
        
        <div class="timestamp">
            Generated on <span id="timestamp"></span>
        </div>
    </div>

    <script>
        // Set timestamp
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        
        // Load and parse coverage data
        fetch('coverage.json')
            .then(response => response.json())
            .then(data => {
                populateCoverageData(data);
            })
            .catch(error => {
                console.error('Error loading coverage data:', error);
                document.getElementById('fileDetails').innerHTML = 
                    '<p style="color: #f56565;">Error loading coverage data. Please check the console for details.</p>';
            });
        
        function populateCoverageData(data) {
            // Calculate overall stats
            let totalLines = 0;
            let coveredLines = 0;
            let fileCount = 0;
            
            if (data.targets) {
                data.targets.forEach(target => {
                    if (target.files) {
                        target.files.forEach(file => {
                            if (file.name && !file.name.includes('Test')) {
                                fileCount++;
                                totalLines += file.lineCoverage?.count || 0;
                                coveredLines += file.lineCoverage?.covered || 0;
                            }
                        });
                    }
                });
            }
            
            const overallCoverage = totalLines > 0 ? Math.round((coveredLines / totalLines) * 100) : 0;
            
            // Update stats
            document.getElementById('totalCoverage').textContent = overallCoverage + '%';
            document.getElementById('linesCovered').textContent = coveredLines.toLocaleString();
            document.getElementById('totalLines').textContent = totalLines.toLocaleString();
            document.getElementById('filesCount').textContent = fileCount;
            
            // Update coverage bar
            document.getElementById('overallBar').style.width = overallCoverage + '%';
            
            // Generate file details
            generateFileDetails(data);
        }
        
        function generateFileDetails(data) {
            const detailsContainer = document.getElementById('fileDetails');
            let html = '';
            
            if (data.targets) {
                data.targets.forEach(target => {
                    if (target.files) {
                        target.files
                            .filter(file => file.name && !file.name.includes('Test'))
                            .sort((a, b) => {
                                const aCoverage = a.lineCoverage ? (a.lineCoverage.covered / a.lineCoverage.count) * 100 : 0;
                                const bCoverage = b.lineCoverage ? (b.lineCoverage.covered / b.lineCoverage.count) * 100 : 0;
                                return bCoverage - aCoverage;
                            })
                            .forEach(file => {
                                const coverage = file.lineCoverage ? Math.round((file.lineCoverage.covered / file.lineCoverage.count) * 100) : 0;
                                const coverageClass = coverage >= 80 ? 'high-coverage' : coverage >= 50 ? 'medium-coverage' : 'low-coverage';
                                
                                html += `
                                    <div class="file-coverage ${coverageClass}">
                                        <div class="file-name">${file.name}</div>
                                        <div style="display: flex; justify-content: space-between; align-items: center;">
                                            <span>${coverage}% covered (${file.lineCoverage?.covered || 0}/${file.lineCoverage?.count || 0} lines)</span>
                                            <div class="coverage-bar" style="width: 200px;">
                                                <div class="coverage-fill" style="width: ${coverage}%"></div>
                                            </div>
                                        </div>
                                    </div>
                                `;
                            });
                    }
                });
            }
            
            if (html === '') {
                html = '<p>No coverage data available.</p>';
            }
            
            detailsContainer.innerHTML = html;
        }
    </script>
</body>
</html>
EOF

# Generate detailed file-by-file coverage using llvm-cov if available
echo -e "${YELLOW}📝 Generating detailed coverage reports...${NC}"

# Find the binary and profdata files
BINARY_PATH=$(find "$DERIVED_DATA_DIR" -name "$PROJECT_NAME" -type f | grep -E "Build.*\.app" | head -1)
PROFDATA_PATH=$(find "$DERIVED_DATA_DIR" -name "*.profdata" | head -1)

if [ -n "$BINARY_PATH" ] && [ -n "$PROFDATA_PATH" ]; then
    echo -e "${GREEN}📱 Found binary: $BINARY_PATH${NC}"
    echo -e "${GREEN}📊 Found profdata: $PROFDATA_PATH${NC}"
    
    # Generate detailed HTML report using llvm-cov
    xcrun llvm-cov show "$BINARY_PATH" \
        -instr-profile="$PROFDATA_PATH" \
        -format=html \
        -output-dir="$DETAILED_HTML_DIR" \
        -ignore-filename-regex=".*Test.*|.*Mock.*|.*Pods.*" \
        2>/dev/null || true
    
    if [ -f "$DETAILED_HTML_DIR/index.html" ]; then
        echo -e "${GREEN}✅ Detailed HTML report generated!${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Binary or profdata not found. Skipping detailed report.${NC}"
fi

# Generate summary statistics
echo -e "${YELLOW}📋 Generating coverage summary...${NC}"
cat > "$COVERAGE_DIR/README.md" << EOF
# Test Coverage Report

Generated on: $(date)

## Quick Access
- 🌐 [HTML Report](html/index.html) - Interactive coverage dashboard
- 📊 [JSON Data](coverage.json) - Raw coverage data
- 📋 [Text Summary](html/coverage_summary.txt) - Command line summary

## Detailed Reports
EOF

if [ -f "$DETAILED_HTML_DIR/index.html" ]; then
    echo "- 🔍 [Detailed HTML Report](detailed_html/index.html) - Line-by-line coverage" >> "$COVERAGE_DIR/README.md"
fi

cat >> "$COVERAGE_DIR/README.md" << EOF

## How to Use
1. Open \`html/index.html\` in your browser for the main dashboard
2. Use the JSON data for CI/CD integration
3. Check the detailed report for line-by-line analysis

## Regenerating
Run \`./generate_coverage.sh\` from the project root.
EOF

# Final output
echo ""
echo -e "${GREEN}🎉 Coverage reports generated successfully!${NC}"
echo ""
echo "📁 Reports location: $COVERAGE_DIR"
echo "🌐 Main report: $HTML_DIR/index.html"

if [ -f "$DETAILED_HTML_DIR/index.html" ]; then
    echo "🔍 Detailed report: $DETAILED_HTML_DIR/index.html"
fi

echo ""
echo -e "${BLUE}🚀 Opening coverage report in browser...${NC}"

# Open the main HTML report in default browser
if command -v open >/dev/null 2>&1; then
    open "$HTML_DIR/index.html"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$HTML_DIR/index.html"
else
    echo -e "${YELLOW}⚠️  Could not open browser automatically. Open $HTML_DIR/index.html manually.${NC}"
fi

echo ""
echo -e "${GREEN}✅ Done! Your coverage report is ready.${NC}"
