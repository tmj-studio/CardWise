# 遠端卡片資料庫 + 自動更新流程 — 設計文件

- 日期:2026-06-09
- 子專案:A —— 遠端卡片資料庫(Remote Card Catalog)與自動更新流程
- 狀態:已核可,待轉實作計畫
- 相關但獨立的後續子專案:B —— Statement credits（報帳折抵）model + UI（另開 spec）

## 背景與問題

CardWise 目前把信用卡回饋資料庫（`CardWise/Resources/cards.json`）**打包在 App 內**。
任何資料更新都必須重新出 build 並送 App Store 審核（約 1–2 天）才會生效，無法做到
「條款常變、馬上更新」。同時現有資料存在錯誤與缺漏（例如 Amex Gold 年費過時、
Hilton Aspire 漏掉自家住宿的高倍率），凸顯了「資料維護不及時」的痛點。

本子專案的目標：**讓卡片資料庫可以遠端更新、不需過 App Store 審核即時生效，並以
自動化流程維護資料、同時設一道安全網避免把錯誤資料推給使用者。**

## 範圍

**包含（子專案 A）**
- 把 `cards.json` 改為「打包後備 + 遠端覆蓋」的雙層架構。
- App 端啟動時抓取、快取、離線後備。
- GitHub Actions 自動抓取流程（LLM 擷取 + 健全性檢查 + 安全自動上線 / 可疑攔下審核）。
- 立即修正既知錯誤資料（Amex Gold 年費、Hilton Aspire 類別）。

**不包含（留待子專案 B）**
- Statement credits（報帳折抵，如 Gold $120 餐飲、Aspire $400 Hilton）的資料模型與 UI。
- 即時套用（抓到新資料當次畫面立即刷新）；本子專案採「下次啟動生效」。

## 已定決策摘要

| 主題 | 決策 |
|---|---|
| 託管 | GitHub raw URL，與打包檔同一份（single source of truth） |
| 抓取時機 | 每次啟動背景抓取 + 本地快取（B1） |
| 生效時機 | 下次啟動生效 |
| 後備 | 快取 → 打包檔 雙層後備，壞資料一律丟棄 |
| 資料維護 | 自動抓取 + 健全性檢查，SAFE 自動上線 / SUSPICIOUS 攔下開 PR（C2+） |
| 抓取機制 | LLM 擷取（Claude API），對版面改動有韌性（D1） |
| 抓取範圍 | 先鎖定熱門卡（Chase / Amex / Citi / Capital One / BoA 主力卡） |

## 設計

### 1. 資料託管與格式

- **單一來源**:`CardWise/Resources/cards.json` 同時作為 App 打包的出廠後備，以及
  線上抓取來源。自動更新流程更新這一份檔，兩用途同步，不會分岔。
- **App 抓取網址**:
  `https://raw.githubusercontent.com/tmj-studio/CardWise/main/CardWise/Resources/cards.json`
- **格式調整**:目前為純陣列，改為帶版本資訊的物件，方便比對新舊與顯示更新時間:

  ```json
  {
    "version": 3,
    "updatedAt": "2026-06-09",
    "cards": [ /* 既有的卡片陣列，欄位不變 */ ]
  }
  ```

  - `version`:單調遞增整數，每次資料變更 +1。
  - `updatedAt`:ISO 日期字串，可用於 App 內顯示「資料更新於」。
  - `CardCatalog` 解碼需改為讀取 `.cards`。

### 2. App 端（新增 `RemoteCatalogService`）

新增 `CardWise/Services/RemoteCatalogService.swift`,職責單一:取得並快取遠端目錄。

- **啟動流程**:App 啟動時背景 async `GET` 遠端 JSON。
- **驗證後才寫入**:回應需能解碼成版本包裝物件與 `[CreditCard]`,且通過基本健全性
  （`cards` 非空、每張卡有 `id` 與 `name`）才寫入本地快取檔（App Support 目錄）。
- **`CardCatalog` 載入順序**:`本地快取（存在且合法）` → `打包的 cards.json（後備）`。
- **生效時機**:本次啟動使用既有快取/打包資料;新抓資料寫入快取,**下次啟動生效**。
- **錯誤處理（靜默,不干擾使用者）**:
  - 無網路 / 遠端不可用 → 用快取,再退回打包檔。**不顯示任何錯誤畫面。**
  - 抓到的 JSON 解碼失敗或為空 → **丟棄,保留既有快取**。壞資料無法進入 App。
  - 只有 `version` 大於目前快取版本時才覆蓋快取（避免回退）。

### 3. 自動更新流程（GitHub Actions）

新增 `.github/workflows/update-cards.yml`,排程**每週一**執行（並支援 `workflow_dispatch` 手動觸發）:

1. **抓取**:對鎖定的熱門卡,抓取對應發卡行回饋頁的文字內容。
2. **LLM 擷取（D1）**:將頁面文字與目標 JSON schema 一併交給 Claude API
   （`ANTHROPIC_API_KEY` repo secret）,回傳結構化卡片 JSON。
3. **健全性檢查腳本**(把關核心),以「新抓取」對比「現有 `cards.json`」:
   - 結構驗證:schema 合法、`category` ∈ 合法 `SpendingCategory` enum、倍率落在合理範圍。
   - 逐卡 diff 分類:
     - **SAFE**(小幅合理變動,例如某卡新增一個類別、note 文字變動)
       → **直接 commit 到 `main`**,自動上線,無需人工。
     - **SUSPICIOUS**(年費變動 >25% 或變號、任一倍率→0、卡片新增/消失、
       擷取失敗或產生空值)→ **開啟標記 `needs-review` 的 PR、附 diff 摘要,不更動 `main`**。
       維護者檢視後一鍵合併放行。
4. **schema 驗證閘**:在每次 push / PR 都執行 schema 驗證腳本,確保手動編輯
   也不會推出格式損壞的檔。

### 4. 立即修正的錯誤資料（seed）

於本子專案內修正既知錯誤（同時進下一個 build 並成為線上種子）。**數字需先對發卡行
當前條款查證後再填**,初步方向:

- **Amex Gold**:`annualFee` 由 250 更新（約 325,以查證為準）。
- **Hilton Aspire**:補上 `hotels` 14x（Hilton 自家住宿）、`airlines` 7x（機票）;既有 `dining` 7x 保留。
- statement credits 屬子專案 B,本輪不處理。

### 5. 測試

- **App 端**:`RemoteCatalogService` 單元測試 —— 合法遠端→使用快取、壞遠端→退回打包、
  離線→使用快取;新版本包裝 JSON 的解碼測試。
- **流程**:健全性分類器（SAFE vs SUSPICIOUS）以假 diff 餵測試 —— 此為安全關鍵,需測試紮實。
- **schema 驗證腳本**:以現有 `cards.json` 為輸入必須通過。

## 預設參數

- 抓取排程:每週一一次。
- SUSPICIOUS 門檻:年費變動 >25% 或變號、任一倍率→0、卡片新增/消失、擷取失敗/空值。
- 熱門卡第一批:Chase / Amex / Citi / Capital One / BoA 主力卡。

## 風險與緩解

- **LLM 擷取錯誤**:由健全性檢查 + SUSPICIOUS 攔截緩解;可疑變動不會自動上線。
- **發卡行 ToS / 反爬**:LLM 擷取降低對精準 selector 的依賴;排程頻率低（每週）。
  若被擋,流程失敗不影響 App（App 仍有快取/打包後備）。
- **raw URL 快取延遲**:raw.githubusercontent.com 有約數分鐘 CDN 快取,對「每週更新」
  情境可接受。
- **資料回退**:以 `version` 單調遞增 + 只在版本變高時覆蓋,避免快取被舊資料覆蓋。

## 未決 / 待實作期確認

- 各發卡行回饋頁的實際 URL 清單(實作時建立)。
- Claude API 擷取 prompt 與 schema 的精確格式(實作時定稿)。
- App 內是否顯示「資料更新於 {updatedAt}」(可選,非必要)。
