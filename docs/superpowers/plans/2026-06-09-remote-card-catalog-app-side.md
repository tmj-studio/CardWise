# 遠端卡片目錄(App 端)實作計畫 — 計畫 A1

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓 CardWise 在啟動時從 GitHub 抓取最新卡片資料、快取於本機,並在離線或資料損壞時退回打包檔,使卡片資料庫不需過 App Store 審核即可更新。

**Architecture:** `cards.json` 改為 `{version, updatedAt, cards:[]}` 包裝格式,同一份檔既打包也線上託管。新增 `RemoteCatalogService` 於啟動時背景抓取、驗證、依版本決定是否寫入快取;`CardCatalog` 載入順序改為「快取 → 打包 → MockData」。抓取/驗證採純函式 + 依賴注入,沿用既有 `AppUpdateChecker` 的可測試模式。

**Tech Stack:** Swift 5.9 / SwiftUI / XCTest / Foundation URLSession;專案由 XcodeGen 從 `project.yml` 產生。

對應 spec:`docs/superpowers/specs/2026-06-09-remote-card-catalog-design.md`(子專案 A 的 App 端部分;自動更新流程為後續計畫 A2)。

---

## 檔案結構

- **Create** `CardWise/Services/RemoteCatalogService.swift` — 抓取/驗證/快取遠端目錄;純決策函式 + async `refresh()`。
- **Modify** `CardWise/Services/CardCatalog.swift` — 新增 `CardCatalogFile` 型別、`decodeFile`、`currentVersion`、快取優先的 `loadCards`。
- **Modify** `CardWise/Resources/cards.json` — 轉成版本包裝格式;修正 Amex Gold / Hilton Aspire 資料。
- **Modify** `CardWise/App/CardWiseApp.swift` — 在啟動 `.task` 中呼叫 `RemoteCatalogService().refresh()`。
- **Create** `CardWiseTests/RemoteCatalogServiceTests.swift` — 驗證/決策/快取邏輯測試。
- **Modify** `CardWiseTests/CardCatalogTests.swift` — 包裝格式解碼與快取優先測試。

每次新增 Swift 檔後需執行 `xcodegen generate` 讓 `.xcodeproj` 納入新檔。

測試指令(全程沿用):
```bash
xcodegen generate
xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

---

## Task 1: `CardCatalogFile` 包裝型別與解碼

讓 `CardCatalog` 能解碼新的 `{version, updatedAt, cards}` 格式,同時仍相容舊的純陣列格式。

**Files:**
- Modify: `CardWise/Services/CardCatalog.swift`
- Modify: `CardWiseTests/CardCatalogTests.swift`

- [ ] **Step 1: 寫失敗測試**

在 `CardWiseTests/CardCatalogTests.swift` 的 `final class CardCatalogTests` 內加入:

```swift
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
```

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO \
  -only-testing:CardWiseTests/CardCatalogTests
```
Expected: 編譯失敗 / FAIL —— `decodeFile` 不存在。

- [ ] **Step 3: 加入 `CardCatalogFile` 與 `decodeFile`,並讓 `decodeCards` 支援包裝格式**

在 `CardWise/Services/CardCatalog.swift`,於 `enum CardCatalog {` 之前加入型別:

```swift
/// On-disk / remote shape of the bundled card database.
struct CardCatalogFile: Decodable {
    let version: Int
    let updatedAt: String   // ISO-8601 date string, display only
    let cards: [CreditCard]
}
```

在 `enum CardCatalog` 內,將既有 `decodeCards(from:)` 替換為以下,並新增 `decodeFile`:

```swift
    static func decodeFile(from data: Data) -> CardCatalogFile? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CardCatalogFile.self, from: data)
    }

    static func decodeCards(from data: Data) -> [CreditCard] {
        // New wrapper format
        if let file = decodeFile(from: data), !file.cards.isEmpty {
            return file.cards
        }
        // Legacy bare-array format
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let cards = try? decoder.decode([CreditCard].self, from: data), !cards.isEmpty {
            return cards
        }
        return MockData.creditCards
    }
```

- [ ] **Step 4: 跑測試確認通過**

Run:
```bash
xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO \
  -only-testing:CardWiseTests/CardCatalogTests
```
Expected: PASS(含既有 `test_decode_fallsBackToMockData_whenDataInvalid` 仍通過)。

- [ ] **Step 5: Commit**

```bash
git add CardWise/Services/CardCatalog.swift CardWiseTests/CardCatalogTests.swift
git commit -m "feat: decode versioned card-catalog wrapper format"
```

---

## Task 2: 將打包 `cards.json` 轉為包裝格式

把現有純陣列包成 `{version, updatedAt, cards}`,讓打包檔與遠端檔同格式。

**Files:**
- Modify: `CardWise/Resources/cards.json`

- [ ] **Step 1: 以指令轉換(保留所有卡片內容)**

Run(用 Python 包裝,避免手動編輯 3600+ 行):
```bash
python3 - <<'PY'
import json
p = "CardWise/Resources/cards.json"
cards = json.load(open(p))
assert isinstance(cards, list) and len(cards) > 100, f"unexpected shape: {type(cards)}"
out = {"version": 1, "updatedAt": "2026-06-09", "cards": cards}
json.dump(out, open(p, "w"), indent=2, ensure_ascii=False)
print("wrapped", len(cards), "cards")
PY
```
Expected:印出 `wrapped <N> cards`(N > 100)。

- [ ] **Step 2: 跑既有目錄測試確認打包檔仍能載入**

Run:
```bash
xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO \
  -only-testing:CardWiseTests/CardCatalogTests/test_loadCards_decodesBundledJSON_withManyCards
```
Expected: PASS(`loadCards` 透過 `decodeCards` 的包裝分支解出 >100 張卡)。

- [ ] **Step 3: Commit**

```bash
git add CardWise/Resources/cards.json
git commit -m "chore: wrap bundled cards.json in versioned envelope"
```

---

## Task 3: `RemoteCatalogService` 驗證與決策(純函式)

決定「抓到的資料要不要寫入快取」:需格式合法、每張卡有 id/name、版本比目前新。

**Files:**
- Create: `CardWise/Services/RemoteCatalogService.swift`
- Create: `CardWiseTests/RemoteCatalogServiceTests.swift`

- [ ] **Step 1: 寫失敗測試**

建立 `CardWiseTests/RemoteCatalogServiceTests.swift`:

```swift
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
        let badCard = #"{"id":"","name":"No ID","issuer":"X","network":"visa","annualFee":0,"rewardType":"cashback","baseReward":1,"baseIsPercentage":true,"categoryRewards":[],"rotatingCategories":null,"selectableConfig":null,"signUpBonus":null,"imageColor":"#000000","imageURL":null}"#
        XCTAssertEqual(RemoteCatalogService.decide(fetched: wrapper(version: 9, cards: badCard), currentVersion: 0), .skip)
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO \
  -only-testing:CardWiseTests/RemoteCatalogServiceTests
```
Expected: 編譯失敗 —— `RemoteCatalogService` 不存在。

- [ ] **Step 3: 建立 `RemoteCatalogService` 與決策函式**

建立 `CardWise/Services/RemoteCatalogService.swift`:

```swift
import Foundation
import os

/// Fetches the latest card catalog from GitHub and caches it on-device.
/// Backend-free and silent on failure: network/parse errors leave the existing
/// cache (and bundled fallback) untouched.
final class RemoteCatalogService {
    static let logger = Logger(subsystem: "com.cardwise.app", category: "RemoteCatalog")

    static let remoteURL = URL(string:
        "https://raw.githubusercontent.com/tmj-studio/CardWise/main/CardWise/Resources/cards.json")!

    /// Cached remote catalog location (Application Support).
    static var defaultCacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("cards-remote.json")
    }

    enum RefreshDecision: Equatable {
        case write(version: Int)
        case skip
    }

    private let url: URL
    private let session: URLSession
    private let cacheURL: URL

    init(url: URL = RemoteCatalogService.remoteURL,
         session: URLSession = .shared,
         cacheURL: URL = RemoteCatalogService.defaultCacheURL) {
        self.url = url
        self.session = session
        self.cacheURL = cacheURL
    }

    // MARK: - Pure helpers (unit tested)

    static func isValid(_ file: CardCatalogFile) -> Bool {
        !file.cards.isEmpty && file.cards.allSatisfy { !$0.id.isEmpty && !$0.name.isEmpty }
    }

    static func decide(fetched: Data, currentVersion: Int) -> RefreshDecision {
        guard let file = CardCatalog.decodeFile(from: fetched),
              isValid(file),
              file.version > currentVersion else { return .skip }
        return .write(version: file.version)
    }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run:
```bash
xcodegen generate
xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO \
  -only-testing:CardWiseTests/RemoteCatalogServiceTests
```
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add CardWise/Services/RemoteCatalogService.swift CardWiseTests/RemoteCatalogServiceTests.swift CardWise.xcodeproj
git commit -m "feat: add RemoteCatalogService validation + version decision"
```

---

## Task 4: 快取優先載入(`CardCatalog`)+ 目前版本

讓 `loadCards` 先讀快取、再退回打包檔;`currentVersion` 提供 `refresh` 比對用的基準。

**Files:**
- Modify: `CardWise/Services/CardCatalog.swift`
- Modify: `CardWiseTests/CardCatalogTests.swift`

- [ ] **Step 1: 寫失敗測試**

在 `CardWiseTests/CardCatalogTests.swift` 內加入:

```swift
    func test_loadCards_prefersCacheOverBundle() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let json = #"""
        {"version":99,"updatedAt":"2026-06-09","cards":[
          {"id":"cached-only","name":"Cached Card","issuer":"X","network":"visa","annualFee":0,
           "rewardType":"cashback","baseReward":1,"baseIsPercentage":true,
           "categoryRewards":[],"rotatingCategories":null,"selectableConfig":null,
           "signUpBonus":null,"imageColor":"#000000","imageURL":null}
        ]}
        """#
        try Data(json.utf8).write(to: tmp)
        let cards = CardCatalog.loadCards(cacheURL: tmp)
        XCTAssertEqual(cards.map(\.id), ["cached-only"])
    }

    func test_loadCards_fallsBackToBundle_whenCacheMissing() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("nope-\(UUID().uuidString).json")
        let cards = CardCatalog.loadCards(cacheURL: missing)
        XCTAssertGreaterThan(cards.count, 100, "should fall back to bundled cards.json")
    }

    func test_loadCards_fallsBackToBundle_whenCacheCorrupt() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupt-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try Data("not json".utf8).write(to: tmp)
        let cards = CardCatalog.loadCards(cacheURL: tmp)
        XCTAssertGreaterThan(cards.count, 100, "corrupt cache must not break loading")
    }

    func test_currentVersion_readsFromCache() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ver-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try Data(#"{"version":42,"updatedAt":"2026-06-09","cards":[{"id":"a","name":"A","issuer":"X","network":"visa","annualFee":0,"rewardType":"cashback","baseReward":1,"baseIsPercentage":true,"categoryRewards":[],"rotatingCategories":null,"selectableConfig":null,"signUpBonus":null,"imageColor":"#000000","imageURL":null}]}"#.utf8).write(to: tmp)
        XCTAssertEqual(CardCatalog.currentVersion(cacheURL: tmp), 42)
    }
```

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO \
  -only-testing:CardWiseTests/CardCatalogTests
```
Expected: 編譯失敗 —— `loadCards(cacheURL:)` / `currentVersion` 不存在。

- [ ] **Step 3: 改寫 `loadCards`、加入快取載入與 `currentVersion`**

在 `CardWise/Services/CardCatalog.swift` 的 `enum CardCatalog` 內,將既有 `loadCards()` 替換為:

```swift
    static func loadCards(cacheURL: URL? = RemoteCatalogService.defaultCacheURL) -> [CreditCard] {
        if let cacheURL, let cached = loadFromCache(cacheURL) {
            return cached
        }
        return loadFromBundle() ?? MockData.creditCards
    }

    static func currentVersion(cacheURL: URL? = RemoteCatalogService.defaultCacheURL) -> Int {
        if let cacheURL, let data = try? Data(contentsOf: cacheURL),
           let file = decodeFile(from: data) {
            return file.version
        }
        if let url = Bundle.main.url(forResource: "cards", withExtension: "json"),
           let data = try? Data(contentsOf: url), let file = decodeFile(from: data) {
            return file.version
        }
        return 0
    }

    private static func loadFromCache(_ cacheURL: URL) -> [CreditCard]? {
        guard let data = try? Data(contentsOf: cacheURL),
              let file = decodeFile(from: data), !file.cards.isEmpty else { return nil }
        return file.cards
    }

    private static func loadFromBundle() -> [CreditCard]? {
        guard let url = Bundle.main.url(forResource: "cards", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            logger.error("cards.json not found in bundle; using MockData")
            #endif
            return nil
        }
        let cards = decodeCards(from: data)
        return cards.isEmpty ? nil : cards
    }
```

- [ ] **Step 4: 跑測試確認通過**

Run:
```bash
xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO \
  -only-testing:CardWiseTests/CardCatalogTests
```
Expected: PASS(含既有 `test_loadCards_*` 測試,因 `loadCards()` 預設參數行為不變)。

- [ ] **Step 5: Commit**

```bash
git add CardWise/Services/CardCatalog.swift CardWiseTests/CardCatalogTests.swift
git commit -m "feat: cache-first card loading with bundled fallback"
```

---

## Task 5: `refresh()` 抓取 + 寫入快取 + 啟動接線

實作實際的網路抓取,並在 App 啟動時觸發。

**Files:**
- Modify: `CardWise/Services/RemoteCatalogService.swift`
- Modify: `CardWise/App/CardWiseApp.swift`
- Modify: `CardWiseTests/RemoteCatalogServiceTests.swift`

- [ ] **Step 1: 寫失敗測試(快取寫入的磁碟往返)**

`refresh()` 走真實網路不易單測,改測「決策為 write 時的落盤行為」。在 `RemoteCatalogServiceTests` 內加入:

```swift
    func test_writeIfNeeded_persistsNewerVersion() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("write-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let service = RemoteCatalogService(cacheURL: tmp)
        service.writeIfNeeded(fetched: wrapper(version: 5), currentVersion: 1)
        XCTAssertEqual(CardCatalog.currentVersion(cacheURL: tmp), 5)
    }

    func test_writeIfNeeded_ignoresOlderVersion() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("write-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try wrapper(version: 8).write(to: tmp)
        let service = RemoteCatalogService(cacheURL: tmp)
        service.writeIfNeeded(fetched: wrapper(version: 3), currentVersion: 8)
        XCTAssertEqual(CardCatalog.currentVersion(cacheURL: tmp), 8, "older fetch must not overwrite cache")
    }
```

- [ ] **Step 2: 跑測試確認失敗**

Run:
```bash
xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO \
  -only-testing:CardWiseTests/RemoteCatalogServiceTests
```
Expected: FAIL —— `writeIfNeeded` 不存在。

- [ ] **Step 3: 加入 `writeIfNeeded` 與 `refresh`**

在 `RemoteCatalogService` 內(`decide` 之後)加入:

```swift
    /// Writes the fetched bytes to the cache only if `decide` approves them.
    func writeIfNeeded(fetched: Data, currentVersion: Int) {
        guard case .write = Self.decide(fetched: fetched, currentVersion: currentVersion) else { return }
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fetched.write(to: cacheURL, options: .atomic)
        } catch {
            Self.logger.debug("catalog cache write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fetches the latest catalog and updates the cache for the next launch.
    /// Silent on any failure.
    func refresh() async {
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                Self.logger.debug("catalog refresh HTTP \(http.statusCode)")
                return
            }
            writeIfNeeded(fetched: data, currentVersion: CardCatalog.currentVersion(cacheURL: cacheURL))
        } catch {
            Self.logger.debug("catalog refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }
```

- [ ] **Step 4: 在 App 啟動接線**

在 `CardWise/App/CardWiseApp.swift` 的 `.task { ... }` 區塊(約第 93–99 行),於 `await updateChecker.checkIfDue()` 之後加入一行:

```swift
                        await RemoteCatalogService().refresh()
```

接線後該區塊應如下:

```swift
                    .task {
                        let notes = WhatsNew.notesToPresent(lastSeen: lastSeenVersion,
                                                            current: AppVersion.current)
                        if !notes.isEmpty { whatsNewNotes = notes }
                        lastSeenVersion = AppVersion.current
                        await updateChecker.checkIfDue()
                        await RemoteCatalogService().refresh()
                    }
```

- [ ] **Step 5: 跑測試 + 建置確認通過**

Run:
```bash
xcodegen generate
xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```
Expected: 全部 PASS,且 App target 編譯成功。

- [ ] **Step 6: Commit**

```bash
git add CardWise/Services/RemoteCatalogService.swift CardWise/App/CardWiseApp.swift CardWiseTests/RemoteCatalogServiceTests.swift
git commit -m "feat: fetch remote catalog on launch and cache for next start"
```

---

## Task 6: 修正既知錯誤資料並 bump 版本

修正你指出的錯誤,並把打包檔 `version` 加 1(讓裝置端視為較新)。

> ⚠️ 下列數字為依現況初判;實作時請先對發卡行**當前**官方條款查證再填,並在 commit message 註明來源日期。

**Files:**
- Modify: `CardWise/Resources/cards.json`

- [ ] **Step 1: 修正 Amex Gold 年費**

將 `id` 為 `american-express-american-express-gold-card` 的卡片,`"annualFee": 250` 改為查證後的值(初判 `325`)。

- [ ] **Step 2: 補上 Hilton Aspire 自家住宿與機票類別**

將 `id` 為 `american-express-hilton-honors-american-express-aspire-card` 的 `categoryRewards`(目前僅 `travel` 7x、`dining` 7x)補為(數值以查證為準):

```json
      {
        "category": "hotels",
        "multiplier": 14,
        "isPercentage": false,
        "cap": null,
        "capPeriod": null
      },
      {
        "category": "airlines",
        "multiplier": 7,
        "isPercentage": false,
        "cap": null,
        "capPeriod": null
      },
```

> `hotels` 與 `airlines` 皆為現有合法 `SpendingCategory`(見 `CardWise/Models/SpendingCategory.swift`)。

- [ ] **Step 3: bump 版本**

將檔案頂層 `"version": 1` 改為 `"version": 2`,並把 `"updatedAt"` 改為當天日期。

- [ ] **Step 4: 驗證仍可載入且資料正確**

Run:
```bash
python3 - <<'PY'
import json
d = json.load(open("CardWise/Resources/cards.json"))
assert d["version"] == 2, d["version"]
g = next(c for c in d["cards"] if c["id"] == "american-express-american-express-gold-card")
a = next(c for c in d["cards"] if c["id"] == "american-express-hilton-honors-american-express-aspire-card")
cats = {r["category"]: r["multiplier"] for r in a["categoryRewards"]}
print("gold fee:", g["annualFee"], "| aspire cats:", cats)
assert "hotels" in cats and "airlines" in cats, cats
print("OK")
PY

xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO \
  -only-testing:CardWiseTests/CardCatalogTests
```
Expected:印出修正後的值與 `OK`;目錄測試 PASS。

- [ ] **Step 5: Commit**

```bash
git add CardWise/Resources/cards.json
git commit -m "fix(data): correct Amex Gold annual fee and Hilton Aspire categories"
```

---

## 完成後

- 計畫 A1 完成後,App 已能在啟動時抓取遠端 `cards.json` 並快取、離線退回打包檔。
- 下一步寫**計畫 A2(自動更新流程)**:`update-cards.yml`、schema 驗證腳本、LLM 擷取、健全性分類器(SAFE 自動 commit / SUSPICIOUS 開 `needs-review` PR)、`ANTHROPIC_API_KEY` secret 設定。
- 提醒:目前 `ios-release.yml` 的 `paths-ignore` 不含 `cards.json`,故資料變更會觸發新 build;A2 設計時需決定資料變更是否要(以及如何)觸發送審。
