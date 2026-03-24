[English](README.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | **繁體中文** | [한국어](README.ko.md)

<p align="center">
  <img src="https://img.shields.io/badge/VRChat_SDK-3.7.1--3.10.2-00b4d8?style=for-the-badge" alt="VRChat SDK" />
  <img src="https://img.shields.io/badge/UdonSharp-C%23_%E2%86%92_Udon-5C2D91?style=for-the-badge&logo=csharp&logoColor=white" alt="UdonSharp" />
  <img src="https://img.shields.io/badge/AI_Agent-Skills_%26_Rules-ff6b35?style=for-the-badge" alt="Agent Skills" />
  <img src="https://img.shields.io/github/license/niaka3dayo/agent-skills-vrc-udon?style=for-the-badge" alt="授權條款" />
</p>

<p align="center">
  <img src="https://img.shields.io/npm/v/agent-skills-vrc-udon?style=flat-square&label=npm" alt="npm 版本" />
  <img src="https://img.shields.io/npm/dm/agent-skills-vrc-udon?style=flat-square&label=downloads" alt="npm 下載量" />
  <img src="https://img.shields.io/github/actions/workflow/status/niaka3dayo/agent-skills-vrc-udon/ci.yml?branch=dev&style=flat-square&label=CI" alt="CI" />
</p>

<h1 align="center">Agent Skills for VRChat UdonSharp</h1>

<p align="center">
  <b>教導 AI 程式碼代理生成正確 UdonSharp 程式碼的技能、規則與驗證掛鉤</b>
</p>

<p align="center">
  <a href="#about">簡介</a> &bull;
  <a href="#install">安裝</a> &bull;
  <a href="#structure">專案結構</a> &bull;
  <a href="#skills">技能</a> &bull;
  <a href="#rules">規則</a> &bull;
  <a href="#hooks">掛鉤</a> &bull;
  <a href="#contributing">貢獻</a> &bull;
  <a href="#disclaimer">免責聲明</a>
</p>

---

<h2 id="about">簡介</h2>

使用 **UdonSharp**（C# → Udon Assembly）進行 VRChat 世界開發時，存在嚴格的編譯限制，與標準 C# 有顯著差異。`List<T>`、`async/await`、`try/catch`、LINQ、lambda 等功能會導致**編譯錯誤**。

本專案為 AI 程式碼代理提供必要知識，使其從一開始就能生成正確的 UdonSharp 程式碼。

| 問題 | 解決方案 |
|------|----------|
| AI 生成 `List<T>`、`async/await` 等不支援的語法 | 規則 + 掛鉤自動偵測並發出警告 |
| 同步變數過度膨脹 | 決策樹 + 資料量預算 |
| 不正確的網路模式 | 模式庫 + 反模式集 |
| SDK 版本間功能差異 | 版本對照表與功能對應 |
| Late Joiner 狀態不一致 | 同步模式選擇框架 |

**本專案並非：**
- VRChat SDK 或 UdonSharp 的發布版本
- Unity 專案（不包含可執行程式碼）
- [VRChat 官方文件](https://creators.vrchat.com/) 的替代品
- AI 行為的完整保證

> **Issues**：歡迎透過 [GitHub Issues](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues) 提交錯誤回報與知識請求。
> **PRs**：不接受 Pull Request。詳情請參閱 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

<h2 id="install">安裝</h2>

> **從 fork/clone 遷移？** — 自 v1.0.0 起，本專案以 **npm 套件** 形式發布。您不再需要 fork 或 clone 此儲存庫。只需在您的 VRChat Unity 專案中執行以下任一安裝指令即可。如果您先前曾 clone 此儲存庫，可以安全地刪除該目錄並改用 npm 安裝方式。

### 方法 1：skills CLI（推薦）

```bash
npx skills add niaka3dayo/agent-skills-vrc-udon
```

此方法使用 [skills.sh](https://skills.sh) 生態系統將技能安裝至您的專案。

### 方法 2：Claude Code 外掛

```bash
claude plugin add niaka3dayo/agent-skills-vrc-udon
```

### 方法 3：npx 直接安裝

```bash
npx agent-skills-vrc-udon
```

選項：

```bash
npx agent-skills-vrc-udon --force    # 覆寫現有檔案
npx agent-skills-vrc-udon --list     # 預覽待安裝檔案（模擬執行）
```

### 方法 4：git clone

```bash
git clone https://github.com/niaka3dayo/agent-skills-vrc-udon.git
```

---

<h2 id="structure">專案結構</h2>

```text
skills/                                  # 所有技能
  unity-vrc-udon-sharp/                 # UdonSharp 核心技能
    SKILL.md                              # 技能定義 + frontmatter
    LICENSE.txt                           # MIT 授權條款
    CHEATSHEET.md                         # 快速參考（1 頁）
    rules/                               # 限制規則
      udonsharp-constraints.md
      udonsharp-networking.md
      udonsharp-sync-selection.md
    hooks/                               # PostToolUse 驗證
      validate-udonsharp.sh
      validate-udonsharp.ps1
    assets/templates/                    # 程式碼範本（4 個檔案）
    references/                          # 詳細文件（11 個檔案）
  unity-vrc-world-sdk-3/                # VRC World SDK 技能
    SKILL.md, LICENSE.txt, CHEATSHEET.md, references/（7 個檔案）
templates/                               # AI 工具設定範本
  CLAUDE.md  AGENTS.md  GEMINI.md        # 透過安裝程式分發給使用者
.claude-plugin/marketplace.json         # Claude Code 外掛註冊
CLAUDE.md                               # 開發指南（僅限本儲存庫）
```

---

<h2 id="skills">技能</h2>

### unity-vrc-udon-sharp

UdonSharp 腳本核心技能。涵蓋編譯限制、網路、事件與範本。

| 領域 | 內容 |
|------|------|
| **限制** | 被禁止的 C# 功能與替代方案（`List<T>` → `DataList`、`async` → `SendCustomEventDelayedSeconds`） |
| **網路** | 所有權模型、Manual/Continuous 同步、FieldChangeCallback、反模式 |
| **NetworkCallable** | SDK 3.8.1+ 參數化網路事件（最多 8 個參數） |
| **持久化** | SDK 3.7.4+ PlayerData/PlayerObject API |
| **動態元件** | SDK 3.10.0+ PhysBones、Contacts、VRC Constraints for Worlds |
| **網頁載入** | String/Image 下載、VRCJson、VRCUrl 限制 |
| **範本** | 4 個入門範本（BasicInteraction、SyncedObject、PlayerSettings、CustomInspector） |

### unity-vrc-world-sdk-3

世界級場景設定、元件配置與效能最佳化。

| 領域 | 內容 |
|------|------|
| **場景設定** | VRC_SceneDescriptor、出生點、Reference Camera |
| **元件** | VRC_Pickup、Station、ObjectSync、Mirror、Portal、CameraDolly |
| **圖層** | VRChat 保留圖層與碰撞矩陣 |
| **效能** | FPS 目標、Quest/Android 限制、最佳化檢查清單 |
| **光照** | 烘焙光照最佳實踐 |
| **音訊/視訊** | 空間音訊、影片播放器選擇（AVPro vs Unity） |
| **上傳** | 建置與上傳流程、上傳前檢查清單 |

---

<h2 id="rules">規則</h2>

規則是在 AI 代理生成程式碼之前提供指引的限制檔案。

| 規則檔案 | 內容 |
|----------|------|
| `udonsharp-constraints` | 被禁止的 C# 功能、程式碼生成規則、屬性、可同步型別 |
| `udonsharp-networking` | 所有權模型、同步模式、反模式、NetworkCallable 限制 |
| `udonsharp-sync-selection` | 同步決策樹、資料量預算目標、6 項最小化原則 |

### 同步決策樹

```text
Q1: 其他玩家是否需要看到？
    否  --> 不需同步（0 位元組）
    是  --> Q2

Q2: Late Joiner 是否需要取得當前狀態？
    否  --> 僅使用事件（0 位元組）
    是  --> Q3

Q3: 是否持續變化？（位置/旋轉）
    是  --> Continuous 同步
    否  --> Manual 同步（最少量的 [UdonSynced]）
```

**目標**：每個 behaviour 低於 50 位元組。中小型世界：合計低於 100 位元組。

---

<h2 id="hooks">驗證掛鉤</h2>

PostToolUse 掛鉤會在 `.cs` 檔案被編輯時自動執行。

| 類別 | 檢查項目 | 嚴重程度 |
|------|----------|----------|
| 禁止功能 | `List<T>`、`async/await`、`try/catch`、LINQ、Coroutine、lambda | ERROR |
| 禁止模式 | `AddListener()`、`StartCoroutine()` | ERROR |
| 網路 | `[UdonSynced]` 缺少 `RequestSerialization()` | WARNING |
| 網路 | `[UdonSynced]` 缺少 `Networking.SetOwner()` | WARNING |
| 同步膨脹 | 每個 behaviour 超過 6 個同步變數 | WARNING |
| 同步膨脹 | `int[]`/`float[]` 同步（建議使用更小的型別） | WARNING |
| 設定不符 | `NoVariableSync` 模式下使用 `[UdonSynced]` 欄位 | ERROR |

同時支援 **Bash**（`validate-udonsharp.sh`）與 **PowerShell**（`validate-udonsharp.ps1`）。

---

## SDK 版本

| SDK 版本 | 主要功能 | 狀態 |
|:--------:|:---------|:----:|
| **3.7.1** | `StringBuilder`、`Regex`、`System.Random` | 已支援 |
| **3.7.4** | Persistence API（PlayerData / PlayerObject） | 已支援 |
| **3.7.6** | 多平台建置與發布（PC + Android） | 已支援 |
| **3.8.0** | PhysBone 依賴排序、Force Kinematic On Remote | 已支援 |
| **3.8.1** | `[NetworkCallable]` 參數化事件、`Others`/`Self` 目標 | 已支援 |
| **3.9.0** | Camera Dolly API、Auto Hold pickup | 已支援 |
| **3.10.0** | VRChat Dynamics for Worlds（PhysBones、Contacts、VRC Constraints） | 已支援 |
| **3.10.1** | 錯誤修正、穩定性改善 | 已支援 |
| **3.10.2** | EventTiming.PostLateUpdate/FixedUpdate、PhysBones 修正、shader 時間全域變數 | 最新穩定版 |

> **注意**：SDK 3.9.0 以下版本已於 2025 年 12 月 2 日棄用。新的世界上傳需使用 3.9.0 以上版本。

---

## 官方資源

| 資源 | 網址 |
|------|------|
| VRChat Creators 文件 | https://creators.vrchat.com/ |
| UdonSharp API 參考 | https://udonsharp.docs.vrchat.com/ |
| VRChat 論壇（問答） | https://ask.vrchat.com/ |
| VRChat Canny（錯誤/功能建議） | https://feedback.vrchat.com/ |
| VRChat 社群 GitHub | https://github.com/vrchat-community |

---

<h2 id="contributing">貢獻</h2>

**歡迎提交 Issues** -- 錯誤回報和知識請求有助於改善本專案。

**不接受 Pull Request** -- 所有修正與更新由維護者進行。

詳情請參閱 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

<h2 id="disclaimer">免責聲明</h2>

> **本專案與 VRChat Inc. 無任何關聯。不暗示任何官方背書、合作關係或從屬關係。**
>
> 「VRChat」、「UdonSharp」、「Udon」及相關名稱/標誌為 VRChat Inc. 的商標。所有商標均歸其各自所有者所有。
>
> 本儲存庫是一個**個人知識庫**，旨在協助 AI 程式碼代理生成正確的 UdonSharp 程式碼。本專案不分發 VRChat SDK 或 UdonSharp 編譯器的任何部分。

### 準確性

- 內容以**「現狀」**提供，不附帶任何保證。請參閱 [LICENSE](LICENSE)。
- 這是一個個人專案。**可能存在錯誤、過時資訊或不完整的內容。** 請務必與 [VRChat 官方文件](https://creators.vrchat.com/) 進行核對。
- 作者不對本儲存庫造成的問題承擔任何責任（建置錯誤、上傳被拒絕、非預期的世界行為等）。
- SDK 涵蓋範圍（3.7.1 - 3.10.2）反映的是最後更新時的狀態。VRChat 發布新版本時，行為可能會有所變更。

### AI 輔助建立

本知識庫在 AI 工具（Claude、Gemini、Codex）的輔助下建立與維護。所有內容均經過審閱，但 AI 生成的部分可能包含細微錯誤。使用時請自行承擔風險。

---

## 授權條款

本專案採用 **MIT 授權條款**。詳情請參閱 [LICENSE](LICENSE)。

您可以在 MIT 授權條款下自由 fork、修改與再發布。本授權條款適用於本儲存庫中的文件、規則、範本與掛鉤。本授權**不**授予 VRChat SDK、UdonSharp 編譯器或其他 VRChat 智慧財產權的任何權利。
