# Statement Credits Implementation Plan（子專案 B：a + c）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 讓每張卡顯示其 statement credits(B-a),並讓使用者以部分金額追蹤當期使用、依日曆週期自然重置(B-c)。

**Architecture:** Catalog 端新增 `StatementCredit`/`CreditCadence` 與 `CreditCard.credits`(隨 cards.json 出貨,唯讀)。使用者端用 `CreditUsage`(複合鍵 `cardID|creditID|periodKey`)存於 SwiftData,沿用 `CloudStore` 既有的 `id+payload` upsert 模式,CloudKit 同步;`periodKey` 由日期+cadence 純函式計算,跨期自然歸零。UI 在 `CardDetailView` 新增「Statement Credits」section。

**Tech Stack:** Swift 5.9 / SwiftUI / SwiftData / XCTest;XcodeGen 從 `project.yml` 產生專案。

對應 spec:`docs/superpowers/specs/2026-06-09-statement-credits-design.md`。

---

## 建置/測試環境(全程沿用)

- 新增 Swift 檔後需 `xcodegen generate` 讓 `.xcodeproj` 納入。
- 模擬器只有一台,**用 UDID**(`name=iPhone 16e` 無法解析):
  ```
  xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
    -destination 'id=1EC68DB2-D6FA-4AAC-B53B-B0BC149614E5' CODE_SIGNING_ALLOWED=NO
  ```
  加 `-only-testing:CardWiseTests/<TestClass>` 可縮小範圍。
- SwiftLint:CI 跑 `swiftlint lint`(非 strict);**單行 > 300 字元是 error**。長 JSON fixture 前加 `// swiftlint:disable:next line_length`。

## 檔案結構

- **Modify** `CardWise/Models/CreditCard.swift` — 新增 `CreditCadence`、`StatementCredit`、`CreditCard.credits`(Task 1)。
- **Create** `CardWise/Utils/CreditPeriod.swift` — `periodKey` 純函式(Task 4)。
- **Create** `CardWise/Models/CreditUsage.swift` — 使用者追蹤的 domain struct(Task 5)。
- **Modify** `CardWise/Services/CloudStore.swift` — `CreditUsageRecord` @Model + load/save(Task 5)。
- **Modify** `CardWise/App/CardWiseApp.swift` — `AppContainer` schema 加 `CreditUsageRecord.self`(Task 5)。
- **Modify** `CardWise/ViewModels/CardViewModel.swift` — `creditUsages` 狀態 + 讀寫方法(Task 6)。
- **Modify** `CardWise/Views/Cards/CardListView.swift` — `CardDetailView` 的「Statement Credits」section(Task 2 唯讀 → Task 6 互動)。
- **Modify** `CardWise/Resources/cards.json` — seed credits(Task 3)。
- **Create** 測試:`CardWiseTests/CreditModelTests.swift`、`CreditPeriodTests.swift`、`CreditUsageStoreTests.swift`。

## 依賴 DAG 與安全平行波次（給 fan-out 執行用）

```
Task 1 (CreditCard.swift)            Task 5 (CloudStore/App/CreditUsage)
      │   └──────────┬──────────┐           （與 Task 1 檔案不重疊,可同波平行）
      ▼              ▼          ▼
 Task 2 (UI顯示)  Task 3(seed)  Task 4(periodKey)
      │                          │
      └─────────────┬────────────┘
                    ▼
            Task 6 (UI互動 + CardViewModel)   （需 Task 2,4,5）
```

- **Wave A(平行):** Task 1 ∥ Task 5 — 觸碰檔案完全不重疊。
- **Wave B(平行,需 Task 1):** Task 2 ∥ Task 3 ∥ Task 4 — `CardListView.swift` / `cards.json` / `CreditPeriod.swift` 互不重疊。
- **Wave C(需 Task 2,4,5):** Task 6 — 與 Task 2 同改 `CardListView.swift`,必須在其後。

**平行執行注意:** 每個平行 agent 在自己的 git worktree 跑(各自 `xcodegen generate` + build,不互相干擾)。整合時各 worktree 的原始碼檔不重疊可乾淨合併;**`CardWise.xcodeproj/project.pbxproj` 不要合併**,改在整合後對合併樹**重跑一次 `xcodegen generate`** 產生單一一致的專案檔,再跑完整測試。

---

## Task 1: Catalog credit 資料模型

**Files:** Modify `CardWise/Models/CreditCard.swift`; Create `CardWiseTests/CreditModelTests.swift`.

- [ ] **Step 1: 寫失敗測試**

建立 `CardWiseTests/CreditModelTests.swift`:
```swift
import XCTest
@testable import CardWise

final class CreditModelTests: XCTestCase {
    func test_statementCredit_decodesFromJSON() throws {
        let json = #"""
        {"id":"amex-gold-dining","description":"Dining credit","amount":10,
         "cadence":"monthly","category":"dining"}
        """#
        let credit = try JSONDecoder().decode(StatementCredit.self, from: Data(json.utf8))
        XCTAssertEqual(credit.id, "amex-gold-dining")
        XCTAssertEqual(credit.amount, 10)
        XCTAssertEqual(credit.cadence, .monthly)
        XCTAssertEqual(credit.category, .dining)
    }

    func test_statementCredit_categoryIsOptional() throws {
        let json = #"{"id":"c1","description":"X","amount":50,"cadence":"annual"}"#
        let credit = try JSONDecoder().decode(StatementCredit.self, from: Data(json.utf8))
        XCTAssertNil(credit.category)
    }

    func test_annualizedAmount_multipliesByPeriodsPerYear() {
        let monthly = StatementCredit(id: "m", description: "", amount: 10, cadence: .monthly, category: nil)
        let annual = StatementCredit(id: "a", description: "", amount: 200, cadence: .annual, category: nil)
        XCTAssertEqual(monthly.annualizedAmount, 120)
        XCTAssertEqual(annual.annualizedAmount, 200)
    }

    func test_creditCard_creditsDefaultsToNil_whenAbsent() {
        // A card decoded from JSON without a "credits" key has nil credits.
        let cards = CardCatalog.loadCards()
        XCTAssertNotNil(cards.first) // sanity: catalog loaded
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `xcodebuild test ... -only-testing:CardWiseTests/CreditModelTests`
Expected: 編譯失敗 — `StatementCredit` 不存在。

- [ ] **Step 3: 實作**

在 `CardWise/Models/CreditCard.swift` 適當位置(如 `RewardType` enum 之後)新增:
```swift
enum CreditCadence: String, Codable, CaseIterable {
    case monthly, quarterly, semiannual, annual

    var displayName: String {
        switch self {
        case .monthly: return "month"
        case .quarterly: return "quarter"
        case .semiannual: return "6 months"
        case .annual: return "year"
        }
    }

    var periodsPerYear: Int {
        switch self {
        case .monthly: return 12
        case .quarterly: return 4
        case .semiannual: return 2
        case .annual: return 1
        }
    }
}

struct StatementCredit: Codable, Identifiable, Equatable {
    let id: String
    let description: String
    let amount: Double               // amount per period
    let cadence: CreditCadence
    let category: SpendingCategory?  // optional, for icon/grouping

    var annualizedAmount: Double { amount * Double(cadence.periodsPerYear) }
}
```

在 `struct CreditCard` 的**最後一個屬性之後**(目前最後是 `let lastUpdated: Date?`)新增:
```swift
    var credits: [StatementCredit]? = nil   // optional + default keeps memberwise init call sites working
```
> 用 `var ... = nil`:`credits` 為 optional ⇒ 解碼缺 key 時為 nil(synthesized `decodeIfPresent`);有預設值 ⇒ `MockData` 等既有 `CreditCard(...)` 建構點不需改。

- [ ] **Step 4: 跑測試確認通過 + 確認既有測試不退化**

Run: `xcodebuild test ... -only-testing:CardWiseTests/CreditModelTests` 然後跑 `-only-testing:CardWiseTests/CardCatalogTests` 與 `-only-testing:CardWiseTests/ModelTests`。
Expected: 全 PASS(`MockData` 仍編譯,因 `credits` 有預設值)。

- [ ] **Step 5: Commit**
```bash
git add CardWise/Models/CreditCard.swift CardWiseTests/CreditModelTests.swift
git commit -m "feat: add StatementCredit catalog model"
```

---

## Task 2: CardDetailView 的「Statement Credits」唯讀顯示

**Files:** Modify `CardWise/Views/Cards/CardListView.swift`(`CardDetailView`,在「Reward Structure」section 之後、「Rotating Categories」之前)。

> 依賴 Task 1。與 Task 6 同檔,必須在 Task 6 之前。此 task 不寫追蹤,只顯示。

- [ ] **Step 1: 加入唯讀 section**

在 `CardDetailView` 的 `Form` 內,緊接「Rewards」section 的閉合 `}` 之後(即現有 `// Rotating Categories` 之前)插入:
```swift
                // Statement Credits (read-only)
                if let credits = card.credits, !credits.isEmpty {
                    Section("Statement Credits") {
                        ForEach(credits) { credit in
                            HStack {
                                Label(credit.description,
                                      systemImage: credit.category?.icon ?? "creditcard")
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("$\(Int(credit.amount)) / \(credit.cadence.displayName)")
                                        .foregroundStyle(Theme.success)
                                    if credit.cadence != .annual {
                                        Text("$\(Int(credit.annualizedAmount))/yr")
                                            .font(.app(.caption2))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                }
```

- [ ] **Step 2: 建置確認編譯通過**

Run: `xcodebuild build -project CardWise.xcodeproj -scheme CardWise -destination 'id=1EC68DB2-D6FA-4AAC-B53B-B0BC149614E5' CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED。(此 task 為 UI,無新單元測試;由 Task 3 的 seed 資料在模擬器中目視驗證。)

- [ ] **Step 3: Commit**
```bash
git add CardWise/Views/Cards/CardListView.swift
git commit -m "feat: show statement credits in card detail (read-only)"
```

---

## Task 3: Seed credit 資料(Amex Gold + Hilton Aspire)

**Files:** Modify `CardWise/Resources/cards.json`。

> 依賴 Task 1(欄位形狀)。⚠️ 金額/週期實作時請對發卡行**當前**官方條款查證,以下為初判結構。

- [ ] **Step 1: 用腳本加入 credits 並 bump 版本**

Run(以 id 精準定位,避免手改大檔):
```bash
python3 - <<'PY'
import json
p = "CardWise/Resources/cards.json"
d = json.load(open(p))
cards = d["cards"]
def card(cid): return next(c for c in cards if c["id"] == cid)

card("american-express-american-express-gold-card")["credits"] = [
    {"id":"amex-gold-dining","description":"Dining credit","amount":10,"cadence":"monthly","category":"dining"},
    {"id":"amex-gold-uber","description":"Uber Cash","amount":10,"cadence":"monthly","category":"transit"},
]
card("american-express-hilton-honors-american-express-aspire-card")["credits"] = [
    {"id":"aspire-resort","description":"Hilton resort credit","amount":200,"cadence":"semiannual","category":"hotels"},
    {"id":"aspire-airline","description":"Airline flight credit","amount":50,"cadence":"quarterly","category":"airlines"},
]
d["version"] = d["version"] + 1
d["updatedAt"] = "2026-06-09"
json.dump(d, open(p,"w"), indent=2, ensure_ascii=False)
print("version:", d["version"])
for cid in ["american-express-american-express-gold-card","american-express-hilton-honors-american-express-aspire-card"]:
    print(cid, "->", [(x["id"], x["amount"], x["cadence"]) for x in card(cid)["credits"]])
PY
```
Expected: 印出 bump 後版本與兩張卡的 credits。

- [ ] **Step 2: 驗證 JSON 仍可載入**

Run: `xcodebuild test ... -only-testing:CardWiseTests/CardCatalogTests`
Expected: PASS。

- [ ] **Step 3: Commit**
```bash
git add CardWise/Resources/cards.json
git commit -m "data: seed statement credits for Amex Gold and Hilton Aspire"
```

---

## Task 4: `periodKey` 純函式

**Files:** Create `CardWise/Utils/CreditPeriod.swift`; Create `CardWiseTests/CreditPeriodTests.swift`。

> 依賴 Task 1(`CreditCadence`)。獨立新檔。

- [ ] **Step 1: 寫失敗測試**

建立 `CardWiseTests/CreditPeriodTests.swift`:
```swift
import XCTest
@testable import CardWise

final class CreditPeriodTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func test_monthly_key() {
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 6, 15), cadence: .monthly), "2026-06")
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 1, 1), cadence: .monthly), "2026-01")
    }
    func test_quarterly_key() {
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 1, 1), cadence: .quarterly), "2026-Q1")
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 6, 30), cadence: .quarterly), "2026-Q2")
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 12, 31), cadence: .quarterly), "2026-Q4")
    }
    func test_semiannual_key() {
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 6, 30), cadence: .semiannual), "2026-H1")
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 7, 1), cadence: .semiannual), "2026-H2")
    }
    func test_annual_key() {
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 3, 9), cadence: .annual), "2026")
    }
}
```

- [ ] **Step 2: 跑測試確認失敗** — `CreditPeriod` 不存在。

- [ ] **Step 3: 實作** — 建立 `CardWise/Utils/CreditPeriod.swift`:
```swift
import Foundation

/// Calendar-period identifier for a credit's cadence. A new period yields a new key,
/// so usage naturally resets without any scheduled job.
enum CreditPeriod {
    static func key(for date: Date, cadence: CreditCadence,
                    calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let year = comps.year ?? 0
        let month = comps.month ?? 1
        switch cadence {
        case .monthly:    return String(format: "%04d-%02d", year, month)
        case .quarterly:  return "\(year)-Q\((month - 1) / 3 + 1)"
        case .semiannual: return "\(year)-H\(month <= 6 ? 1 : 2)"
        case .annual:     return "\(year)"
        }
    }
}
```

- [ ] **Step 4: `xcodegen generate` 後跑測試確認通過** — `-only-testing:CardWiseTests/CreditPeriodTests`。

- [ ] **Step 5: Commit**
```bash
git add CardWise/Utils/CreditPeriod.swift CardWiseTests/CreditPeriodTests.swift CardWise.xcodeproj
git commit -m "feat: add CreditPeriod calendar-key helper"
```

---

## Task 5: 追蹤模型 + CloudStore + schema 註冊

**Files:** Create `CardWise/Models/CreditUsage.swift`; Modify `CardWise/Services/CloudStore.swift`; Modify `CardWise/App/CardWiseApp.swift`; Create `CardWiseTests/CreditUsageStoreTests.swift`。

> 與 Task 1 檔案不重疊,可同波平行。

- [ ] **Step 1: 寫失敗測試**

建立 `CardWiseTests/CreditUsageStoreTests.swift`:
```swift
import XCTest
import SwiftData
@testable import CardWise

@MainActor
final class CreditUsageStoreTests: XCTestCase {
    private func makeStore() throws -> CloudStore {
        let container = try ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self, CreditUsageRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return CloudStore(context: ModelContext(container))
    }

    func test_compositeID_isStable() {
        let u = CreditUsage(cardID: "card1", creditID: "dining", periodKey: "2026-06", amountUsed: 4)
        XCTAssertEqual(u.id, "card1|dining|2026-06")
    }

    func test_saveThenLoad_roundTrips() throws {
        let store = try makeStore()
        let u = CreditUsage(cardID: "card1", creditID: "dining", periodKey: "2026-06", amountUsed: 4)
        try store.saveCreditUsages([u])
        XCTAssertEqual(store.loadCreditUsages(), [u])
    }

    func test_save_prunesRemoved() throws {
        let store = try makeStore()
        let a = CreditUsage(cardID: "c", creditID: "x", periodKey: "2026-06", amountUsed: 1)
        let b = CreditUsage(cardID: "c", creditID: "y", periodKey: "2026-06", amountUsed: 2)
        try store.saveCreditUsages([a, b])
        try store.saveCreditUsages([a])
        XCTAssertEqual(store.loadCreditUsages(), [a])
    }

    func test_save_updatesExisting() throws {
        let store = try makeStore()
        var u = CreditUsage(cardID: "c", creditID: "x", periodKey: "2026-06", amountUsed: 1)
        try store.saveCreditUsages([u])
        u.amountUsed = 9
        try store.saveCreditUsages([u])
        XCTAssertEqual(store.loadCreditUsages().first?.amountUsed, 9)
    }
}
```

- [ ] **Step 2: 跑測試確認失敗** — `CreditUsage` / `CreditUsageRecord` / `saveCreditUsages` 不存在。

- [ ] **Step 3a: 建立 domain struct** `CardWise/Models/CreditUsage.swift`:
```swift
import Foundation

/// Per-user usage of one statement credit within one calendar period.
struct CreditUsage: Codable, Equatable, Identifiable {
    let id: String          // "\(cardID)|\(creditID)|\(periodKey)"
    let cardID: String
    let creditID: String
    let periodKey: String
    var amountUsed: Double

    init(cardID: String, creditID: String, periodKey: String, amountUsed: Double) {
        self.id = "\(cardID)|\(creditID)|\(periodKey)"
        self.cardID = cardID
        self.creditID = creditID
        self.periodKey = periodKey
        self.amountUsed = amountUsed
    }
}
```

- [ ] **Step 3b: 新增 @Model + CloudStore 方法.** 在 `CardWise/Services/CloudStore.swift`,於 `SpendingRecord` 之後新增:
```swift
@Model
final class CreditUsageRecord {
    var id: String = ""
    var payload: Data = Data()
    init(id: String = "", payload: Data = Data()) {
        self.id = id
        self.payload = payload
    }
}
```
在 `CloudStore` 內(於 Spendings 區段之後)新增,完全比照既有 upsert 寫法:
```swift
    // MARK: - Credit Usages
    func loadCreditUsages() -> [CreditUsage] {
        let records = (try? context.fetch(FetchDescriptor<CreditUsageRecord>())) ?? []
        return records.compactMap { try? decoder.decode(CreditUsage.self, from: $0.payload) }
    }

    func saveCreditUsages(_ usages: [CreditUsage]) throws {
        let keepIds = Set(usages.map { $0.id })
        let existing = (try? context.fetch(FetchDescriptor<CreditUsageRecord>())) ?? []
        var byId = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for record in existing where !keepIds.contains(record.id) {
            context.delete(record)
            byId[record.id] = nil
        }
        for usage in usages {
            guard let data = try? encoder.encode(usage) else { continue }
            if let record = byId[usage.id] {
                record.payload = data
            } else {
                context.insert(CreditUsageRecord(id: usage.id, payload: data))
            }
        }
        try context.save()
    }
```

- [ ] **Step 3c: 註冊 schema.** 在 `CardWise/App/CardWiseApp.swift` 的 `AppContainer.shared` 內,把**有效的**(未註解的)`ModelContainer(for:...)` 的型別清單由 `UserCardRecord.self, SpendingRecord.self` 改為 `UserCardRecord.self, SpendingRecord.self, CreditUsageRecord.self`。同時把已註解的 cloud 版與最後的 in-memory fallback 那兩處的型別清單也一併加上 `CreditUsageRecord.self`(保持一致)。

- [ ] **Step 4: `xcodegen generate` 後跑測試確認通過** — `-only-testing:CardWiseTests/CreditUsageStoreTests`,並跑 `-only-testing:CardWiseTests/CloudStoreTests` 確認既有持久化不退化。

- [ ] **Step 5: Commit**
```bash
git add CardWise/Models/CreditUsage.swift CardWise/Services/CloudStore.swift CardWise/App/CardWiseApp.swift CardWiseTests/CreditUsageStoreTests.swift CardWise.xcodeproj
git commit -m "feat: add CreditUsage tracking model and CloudStore persistence"
```

---

## Task 6: 互動追蹤(CardViewModel + CardDetailView)

**Files:** Modify `CardWise/ViewModels/CardViewModel.swift`; Modify `CardWise/Views/Cards/CardListView.swift`; Create `CardWiseTests/CreditUsageViewModelTests.swift`。

> 依賴 Task 2(UI section)、Task 4(`CreditPeriod`)、Task 5(`CreditUsage`/CloudStore)。

- [ ] **Step 1: 寫失敗測試**

建立 `CardWiseTests/CreditUsageViewModelTests.swift`:
```swift
import XCTest
import SwiftData
@testable import CardWise

@MainActor
final class CreditUsageViewModelTests: XCTestCase {
    private func makeVM() throws -> CardViewModel {
        let container = try ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self, CreditUsageRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return CardViewModel(store: CloudStore(context: ModelContext(container)))
    }

    func test_usedAmount_isZero_whenNothingTracked() throws {
        let vm = try makeVM()
        XCTAssertEqual(vm.usedAmount(cardID: "c", creditID: "dining", periodKey: "2026-06"), 0)
    }

    func test_setUsedAmount_thenRead_returnsValue() throws {
        let vm = try makeVM()
        vm.setUsedAmount(8, cardID: "c", creditID: "dining", periodKey: "2026-06")
        XCTAssertEqual(vm.usedAmount(cardID: "c", creditID: "dining", periodKey: "2026-06"), 8)
    }

    func test_setUsedAmount_persistsAcrossReload() throws {
        let container = try ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self, CreditUsageRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = CloudStore(context: ModelContext(container))
        let vm1 = CardViewModel(store: store)
        vm1.setUsedAmount(5, cardID: "c", creditID: "x", periodKey: "2026-06")
        let vm2 = CardViewModel(store: store)
        XCTAssertEqual(vm2.usedAmount(cardID: "c", creditID: "x", periodKey: "2026-06"), 5)
    }

    func test_differentPeriod_isIndependent() throws {
        let vm = try makeVM()
        vm.setUsedAmount(8, cardID: "c", creditID: "dining", periodKey: "2026-06")
        XCTAssertEqual(vm.usedAmount(cardID: "c", creditID: "dining", periodKey: "2026-07"), 0)
    }
}
```

- [ ] **Step 2: 跑測試確認失敗** — `usedAmount`/`setUsedAmount` 不存在。

- [ ] **Step 3a: CardViewModel 加狀態與方法.** 在 `CardWise/ViewModels/CardViewModel.swift`:
於 `@Published var userCards` 之後加 `@Published var creditUsages: [CreditUsage] = []`;在 `init` 的 `userCards = store.loadUserCards()` 之後加 `creditUsages = store.loadCreditUsages()`。在 `// MARK: - Helpers` 之前新增:
```swift
    // MARK: - Statement Credit Usage

    func usedAmount(cardID: String, creditID: String, periodKey: String) -> Double {
        let id = "\(cardID)|\(creditID)|\(periodKey)"
        return creditUsages.first { $0.id == id }?.amountUsed ?? 0
    }

    func setUsedAmount(_ amount: Double, cardID: String, creditID: String, periodKey: String) {
        let usage = CreditUsage(cardID: cardID, creditID: creditID, periodKey: periodKey, amountUsed: amount)
        if let index = creditUsages.firstIndex(where: { $0.id == usage.id }) {
            creditUsages[index] = usage
        } else {
            creditUsages.append(usage)
        }
        try? store.saveCreditUsages(creditUsages)
    }
```

- [ ] **Step 3b: 把 Task 2 的唯讀 section 換成互動版.** 在 `CardDetailView` 中,將 Task 2 加入的「Statement Credits」section 整段替換為下面版本(每筆 credit 顯示「已用 / 剩餘」並可輸入):
```swift
                // Statement Credits
                if let credits = card.credits, !credits.isEmpty {
                    Section("Statement Credits") {
                        ForEach(credits) { credit in
                            let periodKey = CreditPeriod.key(for: Date(), cadence: credit.cadence)
                            let used = cardViewModel.usedAmount(cardID: card.id, creditID: credit.id, periodKey: periodKey)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label(credit.description,
                                          systemImage: credit.category?.icon ?? "creditcard")
                                    Spacer()
                                    Text("$\(Int(credit.amount)) / \(credit.cadence.displayName)")
                                        .foregroundStyle(Theme.success)
                                }
                                HStack {
                                    Text("Used this \(credit.cadence.displayName)")
                                        .font(.app(.caption))
                                        .foregroundStyle(Theme.textSecondary)
                                    Spacer()
                                    Text("$")
                                    TextField("0", text: Binding(
                                        get: { used == 0 ? "" : String(Int(used)) },
                                        set: { newValue in
                                            let entered = min(max(Double(newValue) ?? 0, 0), credit.amount)
                                            cardViewModel.setUsedAmount(entered, cardID: card.id,
                                                                        creditID: credit.id, periodKey: periodKey)
                                        }))
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 60)
                                    Text("/ $\(Int(credit.amount)) · $\(Int(credit.amount - used)) left")
                                        .font(.app(.caption))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
```

- [ ] **Step 4: 跑測試 + 完整建置確認通過**

Run: `xcodebuild test ... -only-testing:CardWiseTests/CreditUsageViewModelTests`,再跑**完整** `xcodebuild test`(全套件)確認無退化。
Expected: 全 PASS。

- [ ] **Step 5: Commit**
```bash
git add CardWise/ViewModels/CardViewModel.swift CardWise/Views/Cards/CardListView.swift CardWiseTests/CreditUsageViewModelTests.swift
git commit -m "feat: track statement credit usage with partial amounts"
```

---

## 完成後

- B-a + B-c 完成後,卡片詳情可見每張卡 credits 並能以部分金額追蹤當期使用、跨期自動歸零。
- 後續(本計畫不含):首頁「本期待用 credits」彙整、淨年費(B-b)、更多卡的 seed credits、「依開卡週年」重置。
