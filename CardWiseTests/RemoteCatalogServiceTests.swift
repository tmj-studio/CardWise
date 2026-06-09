import XCTest
@testable import CardWise

final class RemoteCatalogServiceTests: XCTestCase {

    private func wrapper(version: Int, cards: String = RemoteCatalogServiceTests.validCardJSON) -> Data {
        Data(#"{"version":\#(version),"updatedAt":"2026-06-09","cards":[\#(cards)]}"#.utf8)
    }
    static let validCardJSON = #"""
    {"id":"x-1","name":"Test Card","issuer":"X","network":"visa","annualFee":0,
     "rewardType":"cashback","baseReward":1,"baseIsPercentage":true,
     "categoryRewards":[],"rotatingCategories":null,"selectableConfig":null,
     "signUpBonus":null,"imageColor":"#000000","imageURL":null}
    """#

    func test_decide_writes_whenValidAndNewer() {
        let decision = RemoteCatalogService.decide(fetched: wrapper(version: 5), currentVersion: 1)
        XCTAssertEqual(decision, .write(version: 5))
    }

    func test_decide_skips_whenNotNewer() {
        XCTAssertEqual(RemoteCatalogService.decide(fetched: wrapper(version: 1), currentVersion: 1), .skip)
        XCTAssertEqual(RemoteCatalogService.decide(fetched: wrapper(version: 0), currentVersion: 3), .skip)
    }

    func test_decide_skips_whenGarbage() {
        XCTAssertEqual(RemoteCatalogService.decide(fetched: Data("not json".utf8), currentVersion: 0), .skip)
    }

    func test_decide_skips_whenCardsEmpty() {
        let empty = Data(#"{"version":9,"updatedAt":"2026-06-09","cards":[]}"#.utf8)
        XCTAssertEqual(RemoteCatalogService.decide(fetched: empty, currentVersion: 0), .skip)
    }

    func test_decide_skips_whenCardMissingID() {
        let badCard = ##"{"id":"","name":"No ID","issuer":"X","network":"visa","annualFee":0,"rewardType":"cashback","baseReward":1,"baseIsPercentage":true,"categoryRewards":[],"rotatingCategories":null,"selectableConfig":null,"signUpBonus":null,"imageColor":"#000000","imageURL":null}"##
        XCTAssertEqual(RemoteCatalogService.decide(fetched: wrapper(version: 9, cards: badCard), currentVersion: 0), .skip)
    }
}
