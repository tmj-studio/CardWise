# 本機卡片資料自動更新流程(A2)— 設計文件

- 日期:2026-06-10
- 狀態:已核可(口頭),依使用者要求不單獨 commit spec
- 前置:A1 遠端目錄已上線(cards.json 為 `{version, updatedAt, cards}`,raw URL 託管);
  B/B2 已上線(StatementCredit 等欄位)。
- 決策變更:原 A2 設計(GitHub Actions + ANTHROPIC_API_KEY repo secret)作廢——
  使用者不願付 API 費,改用 **Mac mini 上的 claude CLI(訂閱)**。
  不註冊 CardWise self-hosted runner(public repo + self-hosted runner 有安全風險),
  改用 **launchd** 排程。

## 架構

```
[這台 Mac / 任何 clone]                    [Mac mini (moltbot@richie-mac-mini, ssh alias: mini)]
 pre-push hook                              launchd: 每週一 09:00
   └─ validate_cards.py ◄──共用──┐            └─ update_cards.sh(專用 clone ~/CardWise-data)
                                  │                ├─ git pull main
                                  │                ├─ claude -p(訂閱、headless)更新 cards.json
                                  ├──────────────► ├─ validate_cards.py(不過=中止)
                                  │                ├─ diff_cards.py → SAFE / SUSPICIOUS
                                  │                └─ branch + push + gh pr create(標明分類)
                                  │
                            [人] PR 一鍵 admin-merge → main → App 啟動即抓到
```

## 元件

1. **`scripts/validate_cards.py`** — 確定性驗證器(stdlib only)。檢查:JSON 可解析、頂層
   `{version:int, updatedAt:str, cards:list}`、卡片必要欄位、`cadence` ∈ {monthly,quarterly,
   semiannual,annual}、`category`(若有)∈ SpendingCategory raw 集合、`amount`>0 且 ≤3×年費、
   credit id 全域唯一、卡 id 唯一。`--against <ref>`(預設 origin/main)時另檢查 version 嚴格遞增。
   exit 0/1 + 人類可讀錯誤。
2. **`scripts/diff_cards.py`** — 比較兩份 cards.json(`old new`),輸出變動摘要與分類:
   - SUSPICIOUS:年費變動 >25% 或變號、任一 multiplier → 0、卡片新增/移除、credit 移除、
     credit 金額變動 >50%。
   - 其餘(新增 credit、note/描述、≤25% 年費調整、倍率小調)= SAFE。
   - 輸出 markdown 摘要(給 PR 內文)+ exit code(0=SAFE-only, 2=有 SUSPICIOUS, 1=錯誤)。
3. **pre-push hook**(`scripts/hooks/pre-push` + `scripts/install-hooks.sh`)— push 範圍內
   `cards.json` 有變動時跑 validate(`--against @{push 對象}` 簡化為 origin/main),失敗即擋。
   install 腳本用 `git config core.hooksPath scripts/hooks`。
4. **`scripts/update_cards.sh`** — mini 上的協調器:
   - 在專用 clone(`~/CardWise-data`)`git fetch/reset origin/main`;
   - `claude -p` 給定嚴格 prompt:核對/更新 cards.json 的年費、回饋、credits(僅 $ statement
     credits;查不到不要動;bump version + updatedAt);
   - validate 不過 → 丟棄、log、exit 非 0;無變動 → exit 0;
   - 有變動 → diff_cards 分類 → branch `data/cards-update-<date>` → push →
     `gh pr create`(SAFE:標題 `data: weekly card update (SAFE)`;SUSPICIOUS:
     `⚠️ data: weekly card update (NEEDS REVIEW)` + label)→ log。
5. **launchd**(mini)— `~/Library/LaunchAgents/studio.tmj.cardwise.cards-update.plist`,
   每週一 09:00,跑 update_cards.sh,stdout/err 寫 `~/CardWise-data/update.log`。

## 前置(部署時驗證)
- mini `gh auth status` 可 push tmj-studio/CardWise;`claude` 訂閱憑證有效(已確認存在)。
- mini 建專用 clone `~/CardWise-data`。

## 測試
- validator/differ:stdlib `unittest`(`python3 -m unittest discover scripts/tests`),
  以現有 cards.json + 合成壞資料/diff 案例覆蓋各規則。
- hook:直接以模擬 stdin 跑 hook 腳本驗證擋/放行。
- update_cards.sh:`--dry-run`(跳過 claude 與 push,用注入的假修改走完驗證+分類)。
- 端到端:mini 上手動觸發一次,確認 PR 出現。

## 風險
- LLM 改錯資料 → validator + differ 把關;SUSPICIOUS 不自動上線;App 端 A1 還有
  decode/isValid/version 三層防線。
- mini 憑證過期/額度 → 跑失敗只是沒有 PR,log 可查;不影響 App。
- public repo 安全 → 不註冊 self-hosted runner;launchd 純本機。
