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

    func test_decodeFile_parsesWrapperFormat() {
        let json = #"""
        {"version":7,"updatedAt":"2026-06-09","cards":[
          {"id":"x-1","name":"Test Card","issuer":"X","network":"visa","annualFee":0,
           "rewardType":"cashback","baseReward":1,"baseIsPercentage":true,
           "categoryRewards":[],"rotatingCategories":null,"selectableConfig":null,
           "signUpBonus":null,"imageColor":"#000000","imageURL":null}
        ]}
        """#
        let file = CardCatalog.decodeFile(from: Data(json.utf8))
        XCTAssertEqual(file?.version, 7)
        XCTAssertEqual(file?.updatedAt, "2026-06-09")
        XCTAssertEqual(file?.cards.count, 1)
        XCTAssertEqual(file?.cards.first?.id, "x-1")
    }

    func test_decodeCards_acceptsWrapperFormat() {
        let json = #"""
        {"version":1,"updatedAt":"2026-06-09","cards":[
          {"id":"x-1","name":"Test Card","issuer":"X","network":"visa","annualFee":0,
           "rewardType":"cashback","baseReward":1,"baseIsPercentage":true,
           "categoryRewards":[],"rotatingCategories":null,"selectableConfig":null,
           "signUpBonus":null,"imageColor":"#000000","imageURL":null}
        ]}
        """#
        let cards = CardCatalog.decodeCards(from: Data(json.utf8))
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.id, "x-1")
    }
}
