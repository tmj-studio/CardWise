import XCTest
@testable import SmartCard

final class MerchantDatabaseTests: XCTestCase {

    // MARK: - Category Suggestion Tests

    func testStarbucksIsDining() {
        let category = MerchantDatabase.suggestCategory(for: "Starbucks")
        XCTAssertEqual(category, .dining, "Starbucks should be dining")
    }

    func testChipotleIsDining() {
        let category = MerchantDatabase.suggestCategory(for: "Chipotle")
        XCTAssertEqual(category, .dining, "Chipotle should be dining")
    }

    func testWholeFoodsIsGrocery() {
        let category = MerchantDatabase.suggestCategory(for: "Whole Foods")
        XCTAssertEqual(category, .grocery, "Whole Foods should be grocery")
    }

    func testTraderJoesIsGrocery() {
        let category = MerchantDatabase.suggestCategory(for: "Trader Joe's")
        XCTAssertEqual(category, .grocery, "Trader Joe's should be grocery")
    }

    func testShellIsGas() {
        let category = MerchantDatabase.suggestCategory(for: "Shell")
        XCTAssertEqual(category, .gas, "Shell should be gas")
    }

    func testAmazonIsOnlineShopping() {
        let category = MerchantDatabase.suggestCategory(for: "Amazon")
        XCTAssertEqual(category, .amazon, "Amazon should be amazon category")
    }

    func testNetflixIsStreaming() {
        let category = MerchantDatabase.suggestCategory(for: "Netflix")
        XCTAssertEqual(category, .streaming, "Netflix should be streaming")
    }

    func testUnitedIsTravel() {
        let category = MerchantDatabase.suggestCategory(for: "United Airlines")
        XCTAssertEqual(category, .travel, "United Airlines should be travel")
    }

    func testCVSIsDrugstore() {
        let category = MerchantDatabase.suggestCategory(for: "CVS")
        XCTAssertEqual(category, .drugstore, "CVS should be drugstore")
    }

    func testHomeDepotIsHomeImprovement() {
        let category = MerchantDatabase.suggestCategory(for: "Home Depot")
        XCTAssertEqual(category, .homeImprovement, "Home Depot should be home improvement")
    }

    func testCostcoIsWholesale() {
        let category = MerchantDatabase.suggestCategory(for: "Costco")
        XCTAssertEqual(category, .wholesale, "Costco should be wholesale")
    }

    func testUberIsTransit() {
        let category = MerchantDatabase.suggestCategory(for: "Uber")
        XCTAssertEqual(category, .transit, "Uber should be transit")
    }

    // MARK: - Case Insensitivity Tests

    func testCaseInsensitiveMatching() {
        let category1 = MerchantDatabase.suggestCategory(for: "starbucks")
        let category2 = MerchantDatabase.suggestCategory(for: "STARBUCKS")
        let category3 = MerchantDatabase.suggestCategory(for: "StArBuCkS")

        XCTAssertEqual(category1, .dining)
        XCTAssertEqual(category2, .dining)
        XCTAssertEqual(category3, .dining)
    }

    // MARK: - Partial Match Tests

    func testPartialMatchWorks() {
        let category = MerchantDatabase.suggestCategory(for: "McDonald")
        XCTAssertEqual(category, .dining, "Partial 'McDonald' should match McDonald's")
    }

    // MARK: - Unknown Merchant Tests

    func testUnknownMerchantReturnsNil() {
        let category = MerchantDatabase.suggestCategory(for: "RandomStore12345XYZ")
        XCTAssertNil(category, "Unknown merchant should return nil")
    }

    func testEmptyStringReturnsNil() {
        let category = MerchantDatabase.suggestCategory(for: "")
        XCTAssertNil(category, "Empty string should return nil")
    }

    // MARK: - Search Tests

    func testSearchMerchantsReturnsResults() {
        let results = MerchantDatabase.searchMerchants(query: "star")
        XCTAssertFalse(results.isEmpty, "Search for 'star' should return Starbucks")
        XCTAssertTrue(results.contains { $0.name == "Starbucks" })
    }

    func testSearchMerchantsReturnsMultiple() {
        let results = MerchantDatabase.searchMerchants(query: "a")
        XCTAssertGreaterThan(results.count, 0, "Search for 'a' should return multiple results")
    }

    func testSearchMerchantsEmptyForNoMatch() {
        let results = MerchantDatabase.searchMerchants(query: "xyznotfound123")
        XCTAssertTrue(results.isEmpty, "Should return empty for no matches")
    }
}
