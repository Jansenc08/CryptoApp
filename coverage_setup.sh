#!/bin/bash

# Coverage Setup Script
# Installs required dependencies for generating test coverage reports

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Setting up Test Coverage Dependencies${NC}"
echo "========================================"

# Check if Xcode Command Line Tools are installed
echo -e "${YELLOW}📋 Checking Xcode Command Line Tools...${NC}"
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode Command Line Tools not found!${NC}"
    echo "Please install Xcode and the Command Line Tools:"
    echo "1. Install Xcode from the App Store"
    echo "2. Run: xcode-select --install"
    exit 1
fi
echo -e "${GREEN}✅ Xcode Command Line Tools found${NC}"

# Check if xcpretty is installed (optional but recommended)
echo -e "${YELLOW}🎨 Checking xcpretty (for prettier test output)...${NC}"
if ! command -v xcpretty &> /dev/null; then
    echo -e "${YELLOW}⚠️  xcpretty not found. Installing...${NC}"
    if command -v gem &> /dev/null; then
        sudo gem install xcpretty
        echo -e "${GREEN}✅ xcpretty installed${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not install xcpretty (gem not found). Tests will still work but output won't be as pretty.${NC}"
    fi
else
    echo -e "${GREEN}✅ xcpretty found${NC}"
fi

# Make coverage script executable if it isn't already
echo -e "${YELLOW}🔒 Making coverage script executable...${NC}"
chmod +x generate_coverage.sh
echo -e "${GREEN}✅ Coverage script is executable${NC}"

# Create coverage reports directory structure
echo -e "${YELLOW}📁 Creating coverage reports directory structure...${NC}"
mkdir -p coverage_reports/html
mkdir -p coverage_reports/detailed_html
echo -e "${GREEN}✅ Directory structure created${NC}"

echo ""
echo -e "${GREEN}🎉 Setup complete!${NC}"
echo ""
echo "To generate coverage reports, run:"
echo -e "${BLUE}  ./generate_coverage.sh${NC}"
echo ""
echo "The script will:"
echo "• Run all tests with coverage enabled"
echo "• Generate beautiful HTML reports"
echo "• Automatically open the results in your browser"
echo ""
echo -e "${GREEN}Happy testing! 🧪${NC}"
