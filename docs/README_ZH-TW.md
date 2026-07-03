# CardWise

> 用聰明的推薦,把每一筆消費的信用卡回饋最大化。

CardWise 是一款 iOS App,幫你在每次消費時選出最划算的信用卡,不再錯過任何回饋。

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

---

## 畫面截圖

<p align="center">
  <img src="../Screenshots/home.png" width="200" alt="首頁">
  <img src="../Screenshots/recommend.png" width="200" alt="推薦">
  <img src="../Screenshots/cards.png" width="200" alt="卡片管理">
  <img src="../Screenshots/spending.png" width="200" alt="消費分析">
</p>

---

## 功能特色

| 功能 | 說明 |
|------|------|
| **智慧推薦** | 依商家或消費類別,即時推薦最適合的卡片 |
| **60+ 張信用卡** | 收錄美國主要發卡行的完整回饋資料 |
| **回饋追蹤** | 支援固定、季度輪替、自選三種加成類別 |
| **消費分析** | 互動式圖表呈現消費趨勢 |
| **掃描收據** | OCR 辨識收據,快速記帳 |
| **開卡禮追蹤** | 不錯過任何開卡禮的消費期限 |
| **主畫面小工具** | 不用開 App 也能快速查看推薦 |
| **隱私優先** | 資料全部留在裝置上 — 無帳號、無 CardWise 伺服器(App 僅發出唯讀的卡片資料更新與版本檢查請求) |

### 支援卡片

**美國主要發卡行 60+ 張卡:**
- **Chase** - Sapphire Preferred/Reserve、Freedom Flex/Unlimited、Ink Business、Amazon Prime、United、Southwest、Marriott
- **American Express** - Gold、Platinum、Blue Cash Preferred/Everyday、Delta SkyMiles、Hilton Honors
- **Citi** - Double Cash、Custom Cash、Premier、Strata Premier、Costco Anywhere、AAdvantage
- **Capital One** - Savor/SavorOne、Venture X/Venture、Quicksilver
- **Discover** - it Cash Back、Chrome、Miles、Student
- **Bank of America** - Customized Cash、Premium Rewards、Travel Rewards、Alaska Airlines
- **US Bank** - Cash+、Altitude Go/Connect/Reserve
- **Wells Fargo** - Active Cash、Autograph/Journey
- **其他** - Apple Card、Bilt、PayPal、Venmo、Target RedCard、Walmart

### 支援的回饋類型

| 類型 | 範例 | 運作方式 |
|------|------|----------|
| **固定類別** | Amex Gold 餐飲 4x | 永遠享有加成回饋 |
| **季度輪替類別** | Chase Freedom Flex 5% | 每季更換,需手動啟用 |
| **自選類別** | BoA Customized Cash 3% | 自行選擇加成類別 |

---

## 試用

**TestFlight Beta:** [加入測試](#)*(即將推出)*

---

## 快速開始

### 環境需求

- iOS 17.0+
- Xcode 15+
- Swift 5.9+

### 安裝

```bash
# 複製儲存庫
git clone https://github.com/tmj-studio/CardWise.git

# 用 Xcode 開啟
cd CardWise
open CardWise.xcodeproj

# 建置並執行(Cmd + R)
```

---

## 運作原理

```
+-------------------+     +--------------------+     +-------------------+
|  輸入商家         | --> |  商家 → 類別       | --> |  推薦引擎         |
|  或消費類別       |     |  對應資料庫        |     |                   |
+-------------------+     +--------------------+     +-------------------+
                                                              |
                                                              v
                                                     +-------------------+
                                                     |   最佳卡片 +      |
                                                     |   預估回饋金額    |
                                                     +-------------------+
```

**RecommendationEngine** 會綜合評估你所有的卡片,考量:
- 固定類別的加成倍率
- 本季輪替類別(含啟用狀態)
- 使用者自選的加成類別
- 消費上限與剩餘額度
- 點數/哩程價值

---

## 架構

```
CardWise/
├── App/                    # App 進入點
├── Models/                 # 資料模型
│   ├── CreditCard.swift    # 卡片定義與回饋設定
│   ├── Spending.swift      # 消費紀錄
│   ├── Merchant.swift      # 商家 → 類別對應
│   └── SpendingCategory.swift
├── Views/                  # SwiftUI 畫面(MVVM)
│   ├── Home/               # 主控台
│   ├── Cards/              # 卡片管理
│   ├── Spending/           # 記帳與圖表
│   ├── Recommend/          # 卡片推薦
│   └── Settings/           # 設定
├── ViewModels/             # 狀態管理
├── Services/               # 商業邏輯
│   ├── CloudStore.swift        # SwiftData 持久化(CloudKit 同步已備妥、尚未啟用)
│   ├── CardCatalog.swift       # 卡片目錄:快取優先載入,內建 cards.json 為備援
│   ├── RemoteCatalogService.swift # 從 GitHub 唯讀更新 cards.json
│   ├── RecommendationEngine.swift
│   ├── SpendingCapTracker.swift
│   ├── OCRService.swift
│   ├── NotificationService.swift
│   ├── AppUpdateChecker.swift
│   ├── WidgetDataManager.swift
│   └── …(SearchHistoryManager、KeychainHelper)
├── Resources/
│   └── cards.json          # 內建唯讀回饋資料庫
└── Utils/                  # 擴充與輔助工具
```

---

## 技術架構

| 分類 | 技術 |
|------|------|
| UI | SwiftUI |
| 架構 | MVVM |
| 持久化 | SwiftData(CloudKit 同步已備妥、尚未啟用) |
| 小工具 | WidgetKit |
| OCR | Vision Framework |
| 後端 | 無 CardWise 自營後端 — 僅唯讀的卡片資料與版本檢查請求 |
| 卡片資料 | 內建 `cards.json`,由 `Scripts/` pipeline 每週更新 |

---

## 測試

```bash
# 在 Xcode 中執行所有測試(Cmd + U)

# 或使用指令列
xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

**測試涵蓋範圍**(`CardWiseTests/` 共 15 個測試套件),包含:
- `RecommendationEngineTests` - 卡片推薦邏輯
- `MerchantDatabaseTests` - 商家對應類別
- `ModelTests` / `CreditModelTests` - 資料模型編解碼
- `RemoteCatalogServiceTests` / `CardCatalogTests` - 目錄更新與快取
- `CloudStoreTests`、`CreditPeriodTests`、`CreditUsage*Tests`、`AppUpdateCheckerTests` 等

---

## 參與貢獻

歡迎貢獻!請參閱 [CONTRIBUTING.md](../CONTRIBUTING.md)。

### 快速貢獻指南

1. Fork 本儲存庫
2. 建立功能分支(`git checkout -b feature/AmazingFeature`)
3. 提交變更(`git commit -m 'Add some AmazingFeature'`)
4. 推送分支(`git push origin feature/AmazingFeature`)
5. 開啟 Pull Request

---

## 授權

本專案採用 [MIT License](../LICENSE) 授權。

---

## 支援

- [回報 Bug](https://github.com/tmj-studio/CardWise/issues)
- [功能建議](https://github.com/tmj-studio/CardWise/issues)
- 覺得實用的話,請給個星星!

---

## 致謝

- 信用卡資料來自各發卡行公開資訊
- 圖示使用 SF Symbols

---

<p align="center">
  為信用卡玩家用心打造
</p>
