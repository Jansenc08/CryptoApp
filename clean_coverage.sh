#!/bin/bash

# Clean Coverage Artifacts Script
# Removes all generated coverage reports and build artifacts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🧹 Cleaning Coverage Artifacts${NC}"
echo "==============================="

# Remove coverage reports
if [ -d "coverage_reports" ]; then
    echo -e "${YELLOW}📁 Removing coverage_reports directory...${NC}"
    rm -rf coverage_reports
    echo -e "${GREEN}✅ Coverage reports removed${NC}"
else
    echo -e "${YELLOW}ℹ️  No coverage_reports directory found${NC}"
fi

# Remove DerivedData
if [ -d "DerivedData" ]; then
    echo -e "${YELLOW}📁 Removing DerivedData directory...${NC}"
    rm -rf DerivedData
    echo -e "${GREEN}✅ DerivedData removed${NC}"
else
    echo -e "${YELLOW}ℹ️  No DerivedData directory found${NC}"
fi

# Clean Xcode build folder
echo -e "${YELLOW}🔨 Cleaning Xcode build cache...${NC}"
if command -v xcodebuild &> /dev/null; then
    xcodebuild clean -quiet || true
    echo -e "${GREEN}✅ Xcode build cache cleaned${NC}"
else
    echo -e "${YELLOW}⚠️  xcodebuild not found, skipping build cache clean${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Cleanup complete!${NC}"
echo ""
echo "All coverage artifacts have been removed."
echo "Run ./generate_coverage.sh to regenerate coverage reports."
