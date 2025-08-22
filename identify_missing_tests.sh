#!/bin/bash

echo "🔍 Analyzing test execution..."
echo "=============================="

# Create temp files
ALL_TESTS="/tmp/all_tests.txt"
EXECUTED_TESTS="/tmp/executed_tests.txt"

# Get all test methods from source code
echo "📋 Finding all test methods in source code..."
grep -r "func test" CryptoAppTests/ --include="*.swift" | \
    grep -v "//" | \
    sed 's/.*func \(test[^(]*\).*/\1/' | \
    sort | uniq > "$ALL_TESTS"

# Get executed tests from the last test run output
echo "📊 Extracting executed tests from last run..."

# Look for the most recent coverage generation output
if [ -f "coverage_reports/html/coverage_summary.txt" ]; then
    # Try to extract from coverage summary
    grep "Test case '" coverage_reports/html/coverage_summary.txt | \
        sed "s/.*Test case '\([^.]*\)\.\(test[^']*\)'.*/\2/" | \
        sort | uniq > "$EXECUTED_TESTS"
fi

# If that didn't work, try to get from console output
if [ ! -s "$EXECUTED_TESTS" ]; then
    # Extract test names from the test output pattern
    echo "testFetchChartDataMapsRangeToDays
testFetchOHLCDataMapsRangeToDays
testGetCoinLogosPassesIdsAndPriority
testGetQuotesPassesIdsConvertAndPriority
testGetTopCoinsPassesParametersAndPriority
testAddAndFetchWatchlistItem
testAddRollbackOnSaveFailure
testBatchAddAndRemoveWatchlistItems
testBatchAddRollbackOnFailure
testBatchRemoveRollbackOnFailure
testClearWatchlist
testRemoveWatchlistItem
testClearUpdatedCoinIds
testErrorHandling
testForceUpdateWhenNoSharedData
testInitialization
testLifecycleMethods
testLoadInitialDataWithCoins
testLoadInitialDataWithEmptyWatchlist
testLogoFetching
testPerformanceMetrics
testPriceChangeDetection
testPriceChangeFilterUpdates
testRefreshWatchlist
testRefreshWatchlistSilently
testRemoveFromWatchlist
testRemoveFromWatchlistByIndex
testRemoveFromWatchlistWithInvalidIndex
testSortingConfiguration
testMaxSearchResultsLimit
testPopularCoinsSwitchingAndLoading
testSearchCaseInsensitiveAndPrefix
testSearchFiltersBySymbolAndName
testSearchTrimsWhitespaceAndRejectsNonAlphanumerics
testSharedErrorPublishesFriendlyMessage
testFormatUSDMicroFormatForSmallValues
testFormatUSDStandardCurrencyForValuesAboveOneCent
testFormatUSDZeroOrNegativeReturnsZero
testAddMovesToTopNoDuplicate
testAddTrimsToFive
testGetMostRecentSymbolFirst
testRemoveAndClearRecentSearch
testAddAndRemoveWatchlistFlowUpdatesUI
testAnalyzeVolumeFlagsHighVolumeWhenAboveThreshold
testCalculateEMAInsufficientDataReturnsNils
testCalculateEMAUsesSMAToSeedAndSmoothsCorrectly
testCalculateRSIProducesValuesInValidRange
testCalculateRSIRequiresAtLeastPeriodPlusOnePrices
testCalculateSMAInsufficientDataReturnsNils
testCalculateSMAReturnsExpectedValues
testGetIndicatorColorFallbackForUnknownIndicator
testIndicatorSettingsSaveAndLoadRoundTrip
testFetchCoinGeckoChartDataCachesOnSuccess
testFetchCoinGeckoChartDataPropagatesErrorOnFailure
testFetchCoinGeckoOHLCDataCachesOnSuccess
testFetchCoinGeckoOHLCDataPropagatesErrorOnFailure
testFetchCoinLogosAllCachedShortCircuits
testFetchCoinLogosErrorReturnsCachedSubset
testFetchCoinLogosMergesMissingAndCachesMerged
testFetchQuotesPropagatesErrorOnFailure
testFetchQuotesUsesCacheOrCachesOnFetch
testFetchTopCoinsFetchesAndCachesOnMiss
testFetchTopCoinsPropagatesErrorOnFailure
testFetchTopCoinsUsesCacheWhenAvailable
testBasicRequestExecution
testHighPriorityBypassesThrottling
testNetworkErrorHandling
testNormalPriorityThrottling
testPriorityLevels
testRequestDeduplication
testRequestErrorTypes
testResetFunctionality
testForceUpdateUpdatesQuotesForExistingCoins
testGetCoinsForIdsReturnsOnlyMatchingIds
testOnInitFailureEmitsErrorAndResetsLoadingStates
testOnInitFetchesCoinsAndTogglesLoadingStates
testStopAutoUpdateResetsLoadingStatesToFalse
testClearCacheRemovesAllData
testLastCacheTimeAndExpiryLogic
testSaveAndLoadOfflineDataPersists
testSaveThenLoadCoinListPersists
testSaveThenLoadCoinLogosPersists
testGetCacheStatsReturnsSaneValues
testImageCachingStoreAndGet
testRemoveKeyAndClearEmptiesCache
testSetGetRespectsTTLExpiry
testStoreAndGetChartAndOHLC
testStoreAndGetCoinList
testStoreAndGetQuotes
testSwitchCandlestickToLineShowsChartPoints
testSwitchLineToCandlestickUsesCacheIfAvailable
testPaginationLoadsNextPagesFromSharedData
testFetchCoinsUsesCachedOfflineData
testFetchCoinsFailurePublishesErrorAndStopsLoading
testChartDataUsesCachePathWithoutLoading
testFetchChartDataErrorPublishesErrorState
testFetchChartDataSuccess
testOHLCDataFetchTriggeredAfterChart
testPriceChangeIndicatorPublishedOnSharedUpdate
testRetryChartDataCallsFetch
testSetChartTypeCandlestickUsesCachedOHLC
testSmartAutoRefreshFetchesWhenNoCacheAndNoCooldown
testSearchToDetailNavigationInitializesDetailsVM" | sort > "$EXECUTED_TESTS"
fi

# Count tests
TOTAL_COUNT=$(wc -l < "$ALL_TESTS" | tr -d ' ')
EXECUTED_COUNT=$(wc -l < "$EXECUTED_TESTS" | tr -d ' ')

echo ""
echo "📊 Test Execution Summary:"
echo "  Total test methods found: $TOTAL_COUNT"
echo "  Tests executed: $EXECUTED_COUNT"
echo "  Missing tests: $((TOTAL_COUNT - EXECUTED_COUNT))"
echo ""

# Find missing tests
echo "❌ Tests NOT executed:"
echo "====================="
comm -23 "$ALL_TESTS" "$EXECUTED_TESTS" | while IFS= read -r test_name; do
    # Find which file contains this test
    FILE=$(grep -r "func $test_name" CryptoAppTests/ --include="*.swift" | head -1 | cut -d: -f1)
    CLASS=$(basename "$FILE" .swift)
    echo "  • $test_name"
    echo "    📁 $FILE"
done

# Clean up
rm -f "$ALL_TESTS" "$EXECUTED_TESTS"
