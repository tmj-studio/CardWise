# Statement Credits（顯示 + 部分金額追蹤）— 設計文件

- 日期:2026-06-09
- 子專案:B —— statement credits（報帳折抵）的資料模型、顯示與使用追蹤
- 狀態:已核可,待轉實作計畫
- 前置:子專案 A1(遠端卡片目錄)已出貨;`cards.json` 為 `{version, updatedAt, cards}` 包裝格式。

## 背景與問題

CardWise 的卡片資料庫目前沒有任何「statement credits（報帳折抵）」的概念 —— 例如 Amex Gold
的每月 $10 餐飲抵免、Hilton Aspire 的年度 Hilton resort 抵免。`CreditCard` model 沒有對應欄位,
卡片詳情也不顯示。使用者希望:(1) 看得到每張卡有哪些 credits;(2) 能追蹤自己這一期用了多少、還剩多少。

## 範圍

**包含**
- **B-a**:catalog 端 credits 資料模型 + 在 `CardDetailView` 唯讀顯示 + 第一批 seed 資料。
- **B-c**:每位使用者的使用追蹤（部分金額、日曆週期重置）+ 互動 UI。

**不包含**
- **B-b**:淨年費計算（年費 − credits）。
- 首頁/儀表板的跨卡「本期待用 credits」彙整提醒（資料層做好後屬容易的後續增強）。
- 「依開卡週年」重置（本版一律日曆週期重置）。

## 已定決策摘要

| 主題 | 決策 |
|---|---|
| 範圍 | B-a 顯示 + B-c 追蹤(跳過 B-b 淨年費) |
| 追蹤精細度 | 部分金額(可輸入這期已用多少、顯示剩餘) |
| 重置基準 | 依日曆週期(月/季/半年/年),不需開卡日 |
| 呈現位置 | 只在 `CardDetailView`(首頁彙整為後續) |
| 交付切分 | 先 B-a(顯示)再 B-c(追蹤),各一個實作計畫 |

## 設計

### 1. Catalog 資料模型（B-a,唯讀,隨 `cards.json` 出貨）

新增型別,並在 `CreditCard` 加一個 optional 欄位(optional ⇒ 沒 credits 的卡向後相容):

```swift
enum CreditCadence: String, Codable, CaseIterable {
    case monthly, quarterly, semiannual, annual
}

struct StatementCredit: Codable, Identifiable, Equatable {
    let id: String                  // 穩定 id,如 "amex-gold-dining"
    let description: String         // "Dining credit (Grubhub, Resy…)"
    let amount: Double              // 每期金額,如 10
    let cadence: CreditCadence
    let category: SpendingCategory? // 可選,給 icon / 分組用
}
```

`CreditCard` 新增:`let credits: [StatementCredit]?`

- 月度 $10 餐飲 → `amount: 10, cadence: .monthly`;年化顯示 = `amount × 期數/年`(monthly×12、quarterly×4、semiannual×2、annual×1)。
- 在 `cards.json` 對應卡片物件加 `"credits": [...]` 陣列;`CardCatalog` 的解碼自動帶入(欄位 optional,無需改解碼邏輯)。

### 2. 追蹤資料模型（B-c,每位使用者,SwiftData + CloudKit）

沿用既有 `CloudStore` 的「`@Model` 存 `id + payload(JSON)`、依 id upsert、CloudKit 同步」模式。

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

struct CreditUsage: Codable, Equatable {
    let id: String        // 複合鍵 "\(cardID)|\(creditID)|\(periodKey)"
    let cardID: String
    let creditID: String
    let periodKey: String
    var amountUsed: Double
}
```

**重置靠 `periodKey` 自然發生**(不需排程或重置任務):用今天的日期算出當期 key;查不到當期記錄 ⇒ 這期已用 0。`periodKey` 是純函式,易測:

| cadence | periodKey 範例(2026-06-15) |
|---|---|
| monthly | `2026-06` |
| quarterly | `2026-Q2` |
| semiannual | `2026-H1` |
| annual | `2026` |

`CloudStore` 新增,與既有 `loadSpendings`/`saveSpendings` 同形:
- `func loadCreditUsages() -> [CreditUsage]`
- `func saveCreditUsages(_ usages: [CreditUsage]) throws`(依 id upsert、prune 移除者、`context.save()`)

`AppContainer.shared` 的 `ModelContainer` schema 需加入 `CreditUsageRecord.self`(目前為 `UserCardRecord.self, SpendingRecord.self`)。CloudKit 相容要求:所有屬性有預設值(已符合)、無 unique 約束(沿用 payload 模式即符合)。

### 3. UI（`CardDetailView` 新增「Statement Credits」section）

只有 `card.credits` 非空才顯示此 section(置於「Reward Structure」section 之後)。每筆 credit 一列:

```
┌ Statement Credits ──────────────┐
│ 🍽  Dining          $10 / month │
│     used $4 / $10  ·  $6 left   │  ← 部分金額輸入
│ 🏨  Hilton resort   $400 / year │
│     used $0 / $400 · $400 left  │
└─────────────────────────────────┘
```

- **B-a(唯讀)**:描述 + 「$amount / cadence」+ 年化(如「$120/yr」)。
- **B-c(互動)**:當期已用金額輸入(數字鍵盤,夾在 0…amount)+ 剩餘顯示;變更即寫入當期 `CreditUsage` 並 `saveCreditUsages`。
- 讀取當期已用:`CreditUsage` where `id == "\(cardID)|\(creditID)|\(periodKey(today, cadence))"`,無則 0。
- 透過既有 `CardViewModel`/`CloudStore`(`@MainActor`)存取,沿用現有注入方式。

### 4. Seed credit 資料(第一批)

先填 credits 最有感的幾張,**數字一律對發卡行當前條款查證後再填**:
- **Amex Gold**:餐飲 $10/月、Uber Cash $10/月(以查證為準)。
- **Hilton Aspire**:Hilton resort 抵免(半年期)、機票抵免(季)等。

其餘卡之後陸續補(純資料變更,A1 上線後遠端即時更新,不需送審)。

### 5. 測試

- **純函式**:`periodKey(date:cadence:)` 各 cadence × 邊界日期;年化顯示換算。
- **解碼**:`StatementCredit` 從 cards.json 包裝解出;沒有 `credits` 欄位的卡 ⇒ `credits == nil`,不影響既有解碼測試。
- **追蹤**:`CreditUsage` 當期建立/更新/查詢;跨期(換月)當期歸 0;`CloudStore` round-trip(save→load 一致、prune 生效)。
- **UI 邏輯**:剩餘 = `amount − amountUsed`,夾在 0…amount。

## 交付切分(兩個實作計畫)

- **計畫 B-a**:第 1 段模型 + 第 3 段唯讀顯示 + 第 4 段 seed 資料。完成後卡片詳情可見每張卡 credits。
- **計畫 B-c**:第 2 段追蹤模型(含 `AppContainer` schema 註冊、`CloudStore` 方法、`periodKey`)+ 第 3 段互動 UI。疊在 B-a 上。

## 風險與緩解

- **CloudKit schema 變更**:新增 `CreditUsageRecord` 到既有 container。沿用全屬性預設值 + payload 模式,符合 CloudKit 限制;與既有 `SpendingRecord` 同形,風險低。
- **credit 資料正確性**:seed 數字查證後填;A1 遠端機制讓日後修正即時生效。
- **跨期語意**:以 `periodKey` 區分當期記錄,舊期記錄自然保留為歷史、當期自然歸 0,無需重置邏輯。

## 未決 / 待實作期確認

- 各卡 credits 的精確金額/週期清單(實作 seed 時逐一查證)。
- 「$X / month」與年化文案的最終排版(實作期微調)。
