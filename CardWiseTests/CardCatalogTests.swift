import XCTest
@testable import CardWise

final class CardCatalogTests: XCTestCase {
    func test_loadCards_decodesBundledJSON_withManyCards() {
        let cards = CardCatalog.loadCards()
        XCTAssertGreaterThan(cards.count, 100, "Expected bundled cards.json to decode, got \(cards.count)")
    }

    func test_loadCards_allCardsHaveStableIDs() {
        let cards = CardCatalog.loadCards()
        let ids = Set(cards.map { $0.id })
        XCTAssertEqual(ids.count, cards.count, "Card IDs must be unique")
        XCTAssertFalse(ids.contains(""), "No card may have an empty id")
    }

    func test_decode_fallsBackToMockData_whenDataInvalid() {
        let cards = CardCatalog.decodeCards(from: Data("not json".utf8))
        XCTAssertEqual(cards.count, MockData.creditCards.count)
    }
}
