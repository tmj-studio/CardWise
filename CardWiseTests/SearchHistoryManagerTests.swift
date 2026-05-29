import XCTest
@testable import SmartCard

final class SearchHistoryManagerTests: XCTestCase {

    override func setUpWithError() throws {
        // Clear history before each test
        SearchHistoryManager.shared.clearHistory()
    }

    override func tearDownWithError() throws {
        SearchHistoryManager.shared.clearHistory()
    }

    // MARK: - Add Search Tests

    func testAddSearchSavesItem() {
        SearchHistoryManager.shared.addSearch("Starbucks", category: .dining)

        let history = SearchHistoryManager.shared.history
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.query, "Starbucks")
        XCTAssertEqual(history.first?.spendingCategory, .dining)
    }

    func testAddMultipleSearches() {
        SearchHistoryManager.shared.addSearch("Starbucks", category: .dining)
        SearchHistoryManager.shared.addSearch("Costco", category: .wholesale)
        SearchHistoryManager.shared.addSearch("Shell", category: .gas)

        let history = SearchHistoryManager.shared.history
        XCTAssertEqual(history.count, 3)
    }

    func testMostRecentFirst() {
        SearchHistoryManager.shared.addSearch("First", category: nil)
        SearchHistoryManager.shared.addSearch("Second", category: nil)
        SearchHistoryManager.shared.addSearch("Third", category: nil)

        let history = SearchHistoryManager.shared.history
        XCTAssertEqual(history.first?.query, "Third", "Most recent should be first")
    }

    // MARK: - Duplicate Handling Tests

    func testDuplicateRemovesPrevious() {
        SearchHistoryManager.shared.addSearch("Starbucks", category: .dining)
        SearchHistoryManager.shared.addSearch("Costco", category: .wholesale)
        SearchHistoryManager.shared.addSearch("Starbucks", category: .dining) // Duplicate

        let history = SearchHistoryManager.shared.history
        XCTAssertEqual(history.count, 2, "Duplicate should be removed")
        XCTAssertEqual(history.first?.query, "Starbucks", "Duplicate should move to top")
    }

    func testCaseInsensitiveDuplicateDetection() {
        SearchHistoryManager.shared.addSearch("Starbucks", category: .dining)
        SearchHistoryManager.shared.addSearch("STARBUCKS", category: .dining)

        let history = SearchHistoryManager.shared.history
        XCTAssertEqual(history.count, 1, "Case-insensitive duplicates should be merged")
    }

    // MARK: - Clear History Tests

    func testClearHistory() {
        SearchHistoryManager.shared.addSearch("Starbucks", category: .dining)
        SearchHistoryManager.shared.addSearch("Costco", category: .wholesale)

        SearchHistoryManager.shared.clearHistory()

        let history = SearchHistoryManager.shared.history
        XCTAssertTrue(history.isEmpty, "History should be empty after clear")
    }

    // MARK: - Recent Searches Tests

    func testRecentSearchesLimitsResults() {
        for i in 1...10 {
            SearchHistoryManager.shared.addSearch("Search \(i)", category: nil)
        }

        let recent = SearchHistoryManager.shared.recentSearches(limit: 5)
        XCTAssertEqual(recent.count, 5, "Should limit to 5 results")
        XCTAssertEqual(recent.first?.query, "Search 10", "Should return most recent first")
    }

    // MARK: - Empty Input Tests

    func testEmptyStringNotSaved() {
        SearchHistoryManager.shared.addSearch("", category: nil)
        SearchHistoryManager.shared.addSearch("   ", category: nil)

        let history = SearchHistoryManager.shared.history
        XCTAssertTrue(history.isEmpty, "Empty strings should not be saved")
    }

    // MARK: - Remove Item Tests

    func testRemoveSpecificItem() {
        SearchHistoryManager.shared.addSearch("Starbucks", category: .dining)
        SearchHistoryManager.shared.addSearch("Costco", category: .wholesale)

        let history = SearchHistoryManager.shared.history
        if let item = history.first(where: { $0.query == "Starbucks" }) {
            SearchHistoryManager.shared.removeSearch(item)
        }

        let updatedHistory = SearchHistoryManager.shared.history
        XCTAssertEqual(updatedHistory.count, 1)
        XCTAssertEqual(updatedHistory.first?.query, "Costco")
    }
}
