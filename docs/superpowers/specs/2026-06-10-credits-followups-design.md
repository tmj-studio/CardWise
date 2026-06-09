# Credits Follow-ups — 設計文件

- 日期:2026-06-10
- 子專案:B 後續 —— 首頁 credits 彙整、淨年費、全面補齊有年費卡的 statement credits
- 狀態:已核可,待轉實作計畫
- 前置:子專案 B(`StatementCredit` 模型 + `CreditUsage` 追蹤 + `CreditPeriod`)已出貨於 main。

## 背景

子專案 B 讓卡片能宣告 statement credits 並追蹤當期使用。本輪做三件延伸:
(1) 首頁彙整「本期還沒用完的 credits」當提醒;(2) 卡片詳情顯示「淨年費」;
(3) 把現有資料庫中**所有有年費的卡**的 $ statement credits 研究補齊。

現況:114 張卡,47 張有年費(可能有 credits),67 張無年費(維持 `credits = nil`)。
目前僅 Amex Gold、Hilton Aspire 有 credits。

## 範圍

**包含**
- 首頁「Credits to Use」彙整卡(option A:列出所有本期剩餘>0 的 credits,急迫度排序,含總額)。
- 淨年費(`annualFee − 年化 credits 總額`)顯示於 `CardDetailView`。
- 平行研究補齊 47 張有年費卡的 $ statement credits + 健全性檢查 + 整合進 `cards.json`。

**不包含**
- 無年費卡硬塞 credits(維持 nil)。
- 非 $ 額度福利(免費托運、companion pass、free night 等)—— 不屬 statement credit。
- 「依開卡週年」重置(沿用日曆週期)。
- 卡片列表/列也顯示淨年費(本輪僅詳情頁;之後易加)。

## 已定決策

| 主題 | 決策 |
|---|---|
| 首頁卡內容 | option A:全部本期剩餘>0,月度→季→半年→年排序,頂部單純加總總額 |
| 首頁卡可見性 | 總額為 0 或沒有任何 credits 時整張隱藏 |
| 淨年費位置 | 僅 `CardDetailView`,年費行下方,卡有 credits 才顯示 |
| seed 範圍 | 所有 47 張有年費卡;以平行 research agents 查當前條款;沒 $ 抵免者誠實留空 |

## 設計

### 1. 首頁「Credits to Use」彙整卡

`CardViewModel` 新增兩個 computed（純讀現有狀態,易測）:

```swift
struct UnusedCredit: Identifiable {
    let id: String          // "\(card.id)|\(credit.id)"
    let cardName: String
    let credit: StatementCredit
    let remaining: Double
}

var unusedCreditsThisPeriod: [UnusedCredit] { ... }   // 掃 userCards × 其 card.credits
var totalUnusedCredits: Double { ... }                // 上述 remaining 加總
```

- 對每張 `userCard`,取 `getCard(for:)` 的 `credits`;對每筆 credit 算
  `remaining = credit.amount − usedAmount(cardID: card.id, creditID: credit.id, periodKey: CreditPeriod.key(for: Date(), cadence: credit.cadence))`;
  只保留 `remaining > 0`。
- 排序鍵:cadence 急迫度(monthly < quarterly < semiannual < annual),同級再依 remaining 由大到小。
- 新增 `CreditsToUseCard`(於 `HomeView.swift`,沿用 `CollapsibleHeader` + rows 模式),
  標題「Credits to Use」、副標 `$\(Int(totalUnusedCredits)) available`;
  每列:卡名 · `credit.description` · `$\(Int(remaining)) left`。
  `totalUnusedCredits == 0` 時整張不顯示。放在 `HomeView` 既有卡片序列中(建議在 SpendingCaps 之後)。

### 2. 淨年費（CardDetailView）

`CreditCard` 新增 computed:

```swift
var annualizedCreditTotal: Double { credits?.reduce(0) { $0 + $1.annualizedAmount } ?? 0 }
var netAnnualFee: Double { annualFee - annualizedCreditTotal }
```

在 `CardDetailView` Card Info 區、年費 `Text("$\(Int(card.annualFee)) annual fee")` 下方,
當 `card.credits` 非空時加一行:`−$\(Int(card.annualizedCreditTotal)) credits · $\(Int(card.netAnnualFee)) net/yr`
（用 `Theme.textSecondary` / `.font(.app(.caption))`）。

### 3. 全面補齊 47 張有年費卡的 credits（資料 + 研究）

- **研究**:以平行 research agents（每個負責一小批卡）查各卡**當前官方/權威來源**的
  $ statement credits,回傳結構化 `{id, description, amount, cadence, category}`（cadence ∈
  monthly/quarterly/semiannual/annual;category 為合法 `SpendingCategory` raw 或省略)。
- **健全性檢查**（整合前必過):schema 合法、`amount` 在合理範圍(> 0、≤ 年費的數倍)、
  cadence/category 合法、`id` 唯一且穩定(`<card-slug>-<credit-slug>`)、
  **無 $ 抵免的卡留空陣列或不加 `credits` 欄位**(不硬塞非 $ 福利)。
- **整合**:寫入 `cards.json` 對應卡片,bump `version`。無年費的 67 張卡不動。
- 不確定/查不到可靠來源的卡 → 留空並在計畫記錄,不臆測。

### 4. 測試

- `unusedCreditsThisPeriod`:過濾 remaining>0、排序(月度優先)、跨卡彙整;空狀態。
- `totalUnusedCredits`:加總正確。
- `netAnnualFee` / `annualizedCreditTotal`:有/無 credits、年化換算(月×12 等)。
- `cards.json` 仍可載入(`CardCatalogTests`);抽樣驗證新 credit 結構合法(cadence/category 有效)。

## 交付切分(兩個計畫,可平行)

- **計畫 1(程式)**:第 1 段(首頁卡 + ViewModel)+ 第 2 段(淨年費)+ 第 4 段測試。
- **計畫 2(資料)**:第 3 段研究 + seed 47 張卡 + 健全性檢查 + 版本 bump。
兩者觸碰檔案不重疊(`HomeView.swift`/`CardViewModel.swift`/`CreditCard.swift`/測試 vs `cards.json`),可並行後整合。

## 風險與緩解

- **credit 資料正確性**:research agents 可能抓錯/過時 → 健全性檢查 + 不確定留空 + A1 遠端機制讓日後修正即時生效。
- **首頁總額混加不同 cadence**:刻意設計為「桌上待拿金額」粗估,非精算;文案用「available」。
- **資料量**:47 張 × 平行研究 token 成本較高;已獲使用者同意。

## 未決 / 待實作期確認

- 各卡 credits 的精確清單(研究時逐卡產生,附來源)。
- 首頁卡在 `HomeView` 卡片序列中的最終位置(實作期微調,預設 SpendingCaps 之後)。
