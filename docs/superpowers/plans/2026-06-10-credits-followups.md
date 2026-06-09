# Credits Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 首頁彙整「本期待用 credits」、卡片詳情顯示淨年費,並把資料庫中所有有年費卡的 $ statement credits 研究補齊。

**Architecture:** 純加值於已出貨的 B 子專案(`StatementCredit`/`CreditUsage`/`CreditPeriod`)。`CreditCard` 加淨年費 computed;`CardViewModel` 加跨卡彙整 computed;`HomeView` 加一張 `CreditsToUseCard`;`cards.json` 由平行 research agents 補齊 credits 並過健全性檢查。

**Tech Stack:** Swift 5.9 / SwiftUI / XCTest;XcodeGen。

對應 spec:`docs/superpowers/specs/2026-06-10-credits-followups-design.md`。

---

## 建置/測試環境

- 模擬器 UDID:`id=1EC68DB2-D6FA-4AAC-B53B-B0BC149614E5`(`name=iPhone 16e` 無法解析)。
- 測試:`xcodebuild test -project CardWise.xcodeproj -scheme CardWise -destination 'id=1EC68DB2-D6FA-4AAC-B53B-B0BC149614E5' CODE_SIGNING_ALLOWED=NO [-only-testing:...]`
- 新增/刪除檔案後 `xcodegen generate`。SwiftLint:單行 ≤ 300 字元。

## 檔案結構

- **Modify** `CardWise/Models/CreditCard.swift` — `annualizedCreditTotal` / `netAnnualFee` computed(Task 1)。
- **Modify** `CardWise/Views/Cards/CardListView.swift` — `CardDetailView` 淨年費那行(Task 2)。
- **Modify** `CardWise/ViewModels/CardViewModel.swift` — `UnusedCredit` + `unusedCreditsThisPeriod` + `totalUnusedCredits`(Task 3)。
- **Modify** `CardWise/Views/Home/HomeView.swift` — `CreditsToUseCard` + 接線(Task 4)。
- **Modify** `CardWise/Resources/cards.json` — 47 張有年費卡的 credits(Task 5)。
- **Modify** 測試:`CardWiseTests/CreditModelTests.swift`(Task 1)、新建 `CardWiseTests/UnusedCreditsTests.swift`(Task 3)。

## 依賴 DAG / 平行波次

```
Task 1 (CreditCard.swift)   Task 3 (CardViewModel.swift)   Task 5 (cards.json)
      │                            │                          (獨立,研究+資料)
      ▼                            ▼
Task 2 (CardListView)        Task 4 (HomeView)
```
- **Wave 1（平行）:** Task 1 ∥ Task 3 ∥ Task 5 — 檔案不重疊。
- **Wave 2（平行）:** Task 2(需 Task 1) ∥ Task 4(需 Task 3) — `CardListView.swift` vs `HomeView.swift`,不重疊。
- 平行 agent 各自 worktree;整合時原始碼檔不重疊可乾淨合併,`project.pbxproj` 不要合併,整合後重跑 `xcodegen generate`。

---

## Task 1: CreditCard 淨年費 computed

**Files:** Modify `CardWise/Models/CreditCard.swift`; Modify `CardWiseTests/CreditModelTests.swift`.

- [ ] **Step 1: 寫失敗測試** — 在 `CreditModelTests` 內加入:
```swift
    func test_annualizedCreditTotal_sumsAnnualized() {
        let c = CreditCard(id: "t", name: "T", issuer: "X", network: .amex, annualFee: 325,
            rewardType: .points, baseReward: 1, baseIsPercentage: false, categoryRewards: [],
            rotatingCategories: nil, selectableConfig: nil, signUpBonus: nil,
            imageColor: "#000000", imageURL: nil, lastUpdated: nil,
            credits: [
                StatementCredit(id: "d", description: "Dining", amount: 10, cadence: .monthly, category: .dining),
                StatementCredit(id: "u", description: "Uber", amount: 10, cadence: .monthly, category: .transit)
            ])
        XCTAssertEqual(c.annualizedCreditTotal, 240)   // (10+10)*12
        XCTAssertEqual(c.netAnnualFee, 85)             // 325 - 240
    }

    func test_netAnnualFee_equalsAnnualFee_whenNoCredits() {
        let c = CreditCard(id: "t2", name: "T2", issuer: "X", network: .visa, annualFee: 95,
            rewardType: .cashback, baseReward: 1, baseIsPercentage: true, categoryRewards: [],
            rotatingCategories: nil, selectableConfig: nil, signUpBonus: nil,
            imageColor: "#000000", imageURL: nil, lastUpdated: nil)
        XCTAssertEqual(c.annualizedCreditTotal, 0)
        XCTAssertEqual(c.netAnnualFee, 95)
    }
```

- [ ] **Step 2: 跑測試確認失敗** — `-only-testing:CardWiseTests/CreditModelTests`,`annualizedCreditTotal` 不存在。

- [ ] **Step 3: 實作** — 在 `struct CreditCard` 內(`displayBaseReward` computed 附近)加入:
```swift
    var annualizedCreditTotal: Double { credits?.reduce(0) { $0 + $1.annualizedAmount } ?? 0 }
    var netAnnualFee: Double { annualFee - annualizedCreditTotal }
```

- [ ] **Step 4: 跑測試確認通過** — `-only-testing:CardWiseTests/CreditModelTests` 全 PASS。

- [ ] **Step 5: Commit**
```bash
git add CardWise/Models/CreditCard.swift CardWiseTests/CreditModelTests.swift
git commit -m "feat: add netAnnualFee computed to CreditCard"
```

---

## Task 2: 淨年費顯示（CardDetailView）

**Files:** Modify `CardWise/Views/Cards/CardListView.swift`。依賴 Task 1。

- [ ] **Step 1: 加入顯示行** — 在 `CardDetailView` 的 Card Info `Section` 內,`Text("$\(Int(card.annualFee)) annual fee")` 那個 `Text`(其 `.foregroundStyle(Theme.textSecondary)` 之後、仍在同一個 `VStack(alignment: .leading)` 內)後面加入:
```swift
                            if card.credits?.isEmpty == false {
                                Text("−$\(Int(card.annualizedCreditTotal)) credits · $\(Int(card.netAnnualFee)) net/yr")
                                    .font(.app(.caption))
                                    .foregroundStyle(Theme.textSecondary)
                            }
```

- [ ] **Step 2: 建置確認** — `xcodebuild build ... `,Expected: BUILD SUCCEEDED。

- [ ] **Step 3: Commit**
```bash
git add CardWise/Views/Cards/CardListView.swift
git commit -m "feat: show net annual fee in card detail"
```

---

## Task 3: CardViewModel 跨卡彙整

**Files:** Modify `CardWise/ViewModels/CardViewModel.swift`; Create `CardWiseTests/UnusedCreditsTests.swift`.

- [ ] **Step 1: 寫失敗測試** — 建立 `CardWiseTests/UnusedCreditsTests.swift`:
```swift
import XCTest
import SwiftData
@testable import CardWise

@MainActor
final class UnusedCreditsTests: XCTestCase {
    private func makeVM() throws -> CardViewModel {
        let container = try ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self, CreditUsageRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return CardViewModel(store: CloudStore(context: ModelContext(container)))
    }

    private func card(_ id: String, _ credits: [StatementCredit]) -> CreditCard {
        CreditCard(id: id, name: "Card \(id)", issuer: "X", network: .visa, annualFee: 100,
            rewardType: .points, baseReward: 1, baseIsPercentage: false, categoryRewards: [],
            rotatingCategories: nil, selectableConfig: nil, signUpBonus: nil,
            imageColor: "#000000", imageURL: nil, lastUpdated: nil, credits: credits)
    }

    func test_unusedCredits_listsRemainingAndSortsMonthlyFirst() throws {
        let vm = try makeVM()
        let c = card("c1", [
            StatementCredit(id: "annualx", description: "Annual", amount: 200, cadence: .annual, category: nil),
            StatementCredit(id: "dining", description: "Dining", amount: 10, cadence: .monthly, category: .dining)
        ])
        vm.allCards = [c]
        vm.addCard(c)
        let unused = vm.unusedCreditsThisPeriod
        XCTAssertEqual(unused.map { $0.credit.id }, ["dining", "annualx"]) // monthly before annual
        XCTAssertEqual(unused.first?.remaining, 10)
        XCTAssertEqual(vm.totalUnusedCredits, 210)
    }

    func test_unusedCredits_excludesFullyUsed() throws {
        let vm = try makeVM()
        let c = card("c2", [StatementCredit(id: "dining", description: "Dining", amount: 10, cadence: .monthly, category: .dining)])
        vm.allCards = [c]
        vm.addCard(c)
        let pk = CreditPeriod.key(for: Date(), cadence: .monthly)
        vm.setUsedAmount(10, cardID: "c2", creditID: "dining", periodKey: pk)
        XCTAssertTrue(vm.unusedCreditsThisPeriod.isEmpty)
        XCTAssertEqual(vm.totalUnusedCredits, 0)
    }

    func test_unusedCredits_emptyWhenNoCreditCards() throws {
        let vm = try makeVM()
        XCTAssertTrue(vm.unusedCreditsThisPeriod.isEmpty)
    }
}
```

- [ ] **Step 2: 跑測試確認失敗** — `xcodegen generate` 後 `-only-testing:CardWiseTests/UnusedCreditsTests`,`unusedCreditsThisPeriod` 不存在。

- [ ] **Step 3: 實作** — 在 `CardViewModel` 的 `// MARK: - Helpers` 之前加入:
```swift
    // MARK: - Credits Aggregation

    struct UnusedCredit: Identifiable {
        let id: String          // "\(cardID)|\(creditID)"
        let cardName: String
        let credit: StatementCredit
        let remaining: Double
    }

    var unusedCreditsThisPeriod: [UnusedCredit] {
        var result: [UnusedCredit] = []
        for userCard in userCards {
            guard let card = getCard(for: userCard), let credits = card.credits else { continue }
            for credit in credits {
                let periodKey = CreditPeriod.key(for: Date(), cadence: credit.cadence)
                let remaining = credit.amount - usedAmount(cardID: card.id, creditID: credit.id, periodKey: periodKey)
                if remaining > 0 {
                    result.append(UnusedCredit(id: "\(card.id)|\(credit.id)",
                                               cardName: card.name, credit: credit, remaining: remaining))
                }
            }
        }
        let order: [CreditCadence: Int] = [.monthly: 0, .quarterly: 1, .semiannual: 2, .annual: 3]
        return result.sorted {
            let a = order[$0.credit.cadence] ?? 99
            let b = order[$1.credit.cadence] ?? 99
            return a != b ? a < b : $0.remaining > $1.remaining
        }
    }

    var totalUnusedCredits: Double {
        unusedCreditsThisPeriod.reduce(0) { $0 + $1.remaining }
    }
```

- [ ] **Step 4: 跑測試確認通過** — `-only-testing:CardWiseTests/UnusedCreditsTests` 全 PASS。

- [ ] **Step 5: Commit**
```bash
git add CardWise/ViewModels/CardViewModel.swift CardWiseTests/UnusedCreditsTests.swift CardWise.xcodeproj
git commit -m "feat: aggregate unused statement credits in CardViewModel"
```

---

## Task 4: 首頁 CreditsToUseCard

**Files:** Modify `CardWise/Views/Home/HomeView.swift`。依賴 Task 3。

- [ ] **Step 1: 加入 expand 狀態** — 在 `HomeView` 既有的 `@State private var capsExpanded ...` 等旗標旁加入:
```swift
    @State private var creditsExpanded = true
```

- [ ] **Step 2: 在 body 接線** — 在 `body` 的 `VStack(spacing: 16)` 內,`SpendingCapsCard(...)` 的 `if` 區塊之後加入:
```swift
                    // Credits to Use
                    if cardViewModel.totalUnusedCredits > 0 {
                        CreditsToUseCard(isExpanded: $creditsExpanded)
                    }
```
並把 `creditsExpanded` 加進 Expand All / Collapse All 兩個 menu action(`creditsExpanded = true` / `creditsExpanded = false`)。

- [ ] **Step 3: 新增卡片 view** — 在 `HomeView.swift` 的 `SpendingCapsCard` struct 之後加入:
```swift
struct CreditsToUseCard: View {
    @EnvironmentObject var cardViewModel: CardViewModel
    @Binding var isExpanded: Bool

    var body: some View {
        let items = cardViewModel.unusedCreditsThisPeriod
        return VStack(alignment: .leading, spacing: 12) {
            CollapsibleHeader(
                title: "Credits to Use",
                subtitle: "$\(Int(cardViewModel.totalUnusedCredits)) available",
                subtitleColor: Theme.success,
                isExpanded: $isExpanded
            )

            if isExpanded {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.credit.description)
                                .font(.app(.subheadline))
                            Text("\(item.cardName) · per \(item.credit.cadence.displayName)")
                                .font(.app(.caption2))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Text("$\(Int(item.remaining)) left")
                            .font(.app(.caption))
                            .foregroundStyle(Theme.success)
                    }
                }
            }
        }
        .sectionCard()
    }
}
```

- [ ] **Step 4: 建置確認** — `xcodebuild build ...`,Expected: BUILD SUCCEEDED。

- [ ] **Step 5: Commit**
```bash
git add CardWise/Views/Home/HomeView.swift
git commit -m "feat: home Credits to Use summary card"
```

---

## Task 5: 研究補齊 47 張有年費卡的 credits（資料）

**Files:** Modify `CardWise/Resources/cards.json`。獨立於程式 task。

> 此 task 為「研究 + 資料」,由控制者以平行 research agents 執行,非 TDD 程式。每張有年費卡查當前條款的 **$ statement credits**(非 $ 福利不算)。

- [ ] **Step 1: 列出目標卡** — 取得所有有年費、尚未填 credits 的卡 id:
```bash
python3 - <<'PY'
import json
d = json.load(open("CardWise/Resources/cards.json"))
todo = [(c["id"], c["name"], c["annualFee"]) for c in d["cards"]
        if c.get("annualFee",0) > 0 and not c.get("credits")]
print(len(todo), "cards to research")
for cid,name,fee in todo: print(f"  ${int(fee):>4}  {cid}")
PY
```

- [ ] **Step 2: 平行研究** — 每個 research agent 負責一小批卡(如 5–8 張),查各卡官方/權威來源的 $ statement credits,回傳每卡 JSON 陣列:
  `[{"id":"<card-slug>-<credit-slug>","description":"...","amount":<num>,"cadence":"monthly|quarterly|semiannual|annual","category":"<SpendingCategory raw 或省略>"}]`
  規則:只列 $ 報帳抵免;查不到可靠來源 → 回空陣列;不臆測。

- [ ] **Step 3: 健全性檢查（整合前必過）** — 對彙整結果驗證:
  - JSON/schema 合法;`cadence` ∈ {monthly,quarterly,semiannual,annual};`category` 省略或為合法 `SpendingCategory` raw(見 `CardWise/Models/SpendingCategory.swift`)。
  - `amount` > 0 且 ≤ 該卡年費的 3 倍(超出視為可疑,標記人工複核)。
  - `id` 全域唯一且為 `<card-slug>-<credit-slug>` 格式。
  - 沒有 $ 抵免的卡 → 不加 `credits` 欄位(維持 nil)。

- [ ] **Step 4: 寫入並 bump 版本** — 將通過檢查的 credits 寫入 `cards.json` 對應卡片,`version` += 1,`updatedAt` 設為當天。用腳本套用(不手改大檔)。

- [ ] **Step 5: 驗證載入** — 
```bash
xcodebuild test -project CardWise.xcodeproj -scheme CardWise -destination 'id=1EC68DB2-D6FA-4AAC-B53B-B0BC149614E5' CODE_SIGNING_ALLOWED=NO -only-testing:CardWiseTests/CardCatalogTests
```
並抽樣印出幾張卡確認結構正確。Expected: PASS。

- [ ] **Step 6: Commit**
```bash
git add CardWise/Resources/cards.json
git commit -m "data: research and seed statement credits for all fee cards"
```

---

## 完成後

- 首頁出現「Credits to Use」提醒、詳情頁顯示淨年費、資料庫所有有年費卡的 $ credits 補齊(查不到者誠實留空)。
- 之後:A2 自動更新流程(本機 hook)接手日後 credits/資料維護;首頁卡點擊跳轉卡片詳情(可選增強)。
