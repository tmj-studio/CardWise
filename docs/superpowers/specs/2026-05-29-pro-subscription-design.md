# SmartCard Pro 訂閱（StoreKit 2）— 設計文件

- **日期**: 2026-05-29
- **狀態**: 已核准，待實作
- **範圍**: 為 SmartCard iOS app 加入 StoreKit 2 原生訂閱變現機制（目前變現為 0%）

## 背景與目標

SmartCard 技術完成度高（推薦引擎、Plaid 後端、測試、安全皆已實作），但**沒有任何變現機制**——無 StoreKit / IAP / 訂閱 / affiliate。本子專案補上第一個收入來源：StoreKit 2 原生訂閱。

設計決定（已與使用者確認）：
- **保留 Plaid**（Production 為外部申請流程，非本 spec 範圍）
- **StoreKit 2 原生**（不使用 RevenueCat，避免第三方依賴與抽成）
- **付費牆切分**：把「自動化」鎖進 Pro
- **定價**：月費 $2.99 + 年費 $19.99

非目標（YAGNI）：
- 不自架 receipt 驗證後端（StoreKit 2 本地驗證足夠）
- 不做 lifetime 買斷
- 不動 Plaid 後端、不處理美/台市場決策（屬後續子專案）

## 免費 vs Pro 切分

| 免費 | Pro |
|------|-----|
| 手動選卡推薦 | 無限卡片 |
| 最多 3 張卡 | Plaid 自動連銀行偵測 |
| 基本消費紀錄 | 進階分析圖表、年度回饋總結 |
| | 回饋上限快滿提醒 |
| | Widget |

`freeCardLimit = 3`

## 架構

### 1. `SubscriptionManager`（新增 `Services/SubscriptionManager.swift`）
- `@MainActor` `ObservableObject` 單例，仿現有 service 模式（如 `PlaidService.shared`）
- 狀態：
  - `@Published var isPro: Bool`
  - `@Published var products: [Product]`
  - `@Published var purchaseState`（idle / loading / pending / failed）
- 行為：
  - `loadProducts()` → `Product.products(for: productIDs)`
  - `purchase(_ product: Product)`
  - `restorePurchases()` → `AppStore.sync()`
  - `updateEntitlements()` → 讀 `Transaction.currentEntitlements`，設定 `isPro`
  - 啟動一個長駐 task 監聽 `Transaction.updates`，收到即 `updateEntitlements()`
- 驗證：使用 StoreKit 2 內建 `VerificationResult`，拒絕 `.unverified`。不需自架後端。

### 2. App Store Connect 產品（使用者於後台建立；code 用對應 ID）
- 訂閱群組：`SmartCard Pro`
- `com.smartcard.app.pro.monthly` → $2.99 / 月
- `com.smartcard.app.pro.yearly` → $19.99 / 年
- 本地測試：新增 `SmartCard.storekit` configuration 檔（不依賴真實後台即可在模擬器測試購買流程）

### 3. `PaywallView`（新增 `Views/Paywall/PaywallView.swift`）
- 以 `.sheet` 呈現
- 內容：功能對照表、月/年方案按鈕（年費標示「省 ~44%」）、購買按鈕、**還原購買**、條款與隱私政策連結（App Store 強制要求）
- 載入 / 購買 / 失敗狀態的 UI

### 4. 權限閘（Gating）
將純邏輯抽成可測試的 `SubscriptionGate`（純函式 / struct，不依賴 StoreKit）：
- `func canAddCard(currentCount: Int, isPro: Bool) -> Bool` → `isPro || currentCount < freeCardLimit`
- 功能旗標：`func isFeatureUnlocked(_ feature: ProFeature, isPro: Bool) -> Bool`
  - `ProFeature`: `.bankLinking`, `.advancedAnalytics`, `.capAlerts`, `.widget`, `.unlimitedCards`

整合點：
- `CardListView` 加卡前呼叫 `canAddCard(...)`，false → 呈現 `PaywallView`
- `LinkBankView`（Plaid）：`!isPro` → 呈現 `PaywallView`
- `SpendingChartsView`（進階分析）：`!isPro` → 鎖 + Paywall 入口
- 上限提醒、Widget：同樣依 `isPro` 判斷

### 5. 注入
`SmartCardApp` 新增 `@StateObject private var subscription = SubscriptionManager.shared`，透過 `.environmentObject(subscription)` 注入 `MainTabView` 與 `OnboardingView`，與現有 `cardViewModel` / `spendingViewModel` 模式一致。

## 資料流

```
App 啟動
  → SubscriptionManager.updateEntitlements() 讀 currentEntitlements
  → 設定 isPro
  → 各 View 透過 @EnvironmentObject 讀取，決定鎖/開
使用者購買
  → purchase() → 驗證 Transaction
  → Transaction.updates 觸發 → updateEntitlements()
  → isPro 更新 → SwiftUI 自動重繪解鎖
```

## 錯誤處理
- 產品載入失敗：Paywall 顯示「無法載入方案，稍後再試」+ 重試按鈕
- 購買取消（`.userCancelled`）：靜默回 Paywall，不顯示錯誤
- 購買失敗：顯示友善錯誤訊息
- 待處理（`.pending`，家長核准）：顯示 pending 狀態，待 `Transaction.updates` 完成

## 測試（TDD）
- **`SubscriptionGate` 純邏輯單元測試**（不需 StoreKit）：
  - 免費用戶第 4 張卡被擋、前 3 張可加
  - Pro 用戶無限卡
  - 各 `ProFeature` 在免費 / Pro 下的鎖定狀態
- **`SubscriptionManager` 流程測試**：使用 `SmartCard.storekit` 設定檔 + StoreKitTest 框架測購買 / 還原 / 權限更新
- 目標涵蓋率維持專案標準

## 上架影響
- App Store 審查要求付費牆內含條款與隱私政策連結（已納入 PaywallView 設計）
- 需在 App Store Connect 設定訂閱產品與在地化價格後，此功能方能於正式環境運作（沙盒測試不受影響）

## 後續（非本 spec）
- Plaid Production 申請（外部行政流程）
- 行政缺口清理：support email、App Store 評分 URL、線上隱私政策 URL
- 後續變現：辦卡導購 / affiliate（待市場決策）
