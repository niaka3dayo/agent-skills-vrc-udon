[English](README.md) | [日本語](README.ja.md) | **简体中文** | [繁體中文](README.zh-TW.md) | [한국어](README.ko.md)

<p align="center">
  <img src="https://img.shields.io/badge/VRChat_SDK-3.7.1--3.10.2-00b4d8?style=for-the-badge" alt="VRChat SDK" />
  <img src="https://img.shields.io/badge/UdonSharp-C%23_%E2%86%92_Udon-5C2D91?style=for-the-badge&logo=csharp&logoColor=white" alt="UdonSharp" />
  <img src="https://img.shields.io/badge/AI_Agent-Skills_%26_Rules-ff6b35?style=for-the-badge" alt="AI Agent 技能" />
  <img src="https://img.shields.io/github/license/niaka3dayo/agent-skills-vrc-udon?style=for-the-badge" alt="许可证" />
</p>

<p align="center">
  <img src="https://img.shields.io/npm/v/agent-skills-vrc-udon?style=flat-square&label=npm" alt="npm 版本" />
  <img src="https://img.shields.io/npm/dm/agent-skills-vrc-udon?style=flat-square&label=downloads" alt="npm 下载量" />
  <img src="https://img.shields.io/github/actions/workflow/status/niaka3dayo/agent-skills-vrc-udon/ci.yml?branch=dev&style=flat-square&label=CI" alt="CI" />
</p>

<h1 align="center">Agent Skills for VRChat UdonSharp</h1>

<p align="center">
  <b>帮助 AI 编码代理生成正确 UdonSharp 代码的技能、规则和验证钩子集</b>
</p>

<p align="center">
  <a href="#about">简介</a> &bull;
  <a href="#install">安装</a> &bull;
  <a href="#structure">项目结构</a> &bull;
  <a href="#skills">技能</a> &bull;
  <a href="#rules">规则</a> &bull;
  <a href="#hooks">钩子</a> &bull;
  <a href="#contributing">参与贡献</a> &bull;
  <a href="#disclaimer">免责声明</a>
</p>

---

<h2 id="about">简介</h2>

使用 **UdonSharp**（C# &rarr; Udon Assembly）进行 VRChat 世界开发时，存在与标准 C# 截然不同的严格编译限制。`List<T>`、`async/await`、`try/catch`、LINQ 和 lambda 表达式等特性都会导致**编译错误**。

本仓库为 AI 编码代理提供必要的知识，使其从一开始就能生成正确的 UdonSharp 代码。

| 问题 | 解决方案 |
|------|----------|
| AI 生成 `List<T>`、`async/await` 等不兼容代码 | 规则 + 钩子自动检测并发出警告 |
| 同步变量膨胀 | 决策树 + 数据预算 |
| 错误的网络模式 | 模式库 + 反模式集 |
| SDK 版本间的功能差异 | 版本表 + 功能映射 |
| 后加入者的状态不一致 | 同步模式选择框架 |

**本项目不是：**
- VRChat SDK 或 UdonSharp 的分发包
- Unity 项目（不包含可执行代码）
- [VRChat 官方文档](https://creators.vrchat.com/) 的替代品
- 对所有 AI 行为的保证

> **Issues**：欢迎通过 [GitHub Issues](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues) 提交 Bug 报告和知识请求。
> **PRs**：不接受 Pull Request。详情请参阅 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

<h2 id="install">安装</h2>

> **从 fork/clone 迁移？** &mdash; 自 v1.0.0 起，本项目以 **npm 包** 的形式分发。你不再需要 fork 或 clone 仓库，只需在你的 VRChat Unity 项目中执行以下任一安装命令即可。如果你之前 clone 过本仓库，可以放心删除该目录并切换到 npm 安装方式。

### 方式一：skills CLI（推荐）

```bash
npx skills add niaka3dayo/agent-skills-vrc-udon
```

通过 [skills.sh](https://skills.sh) 生态系统将技能安装到你的项目中。

### 方式二：Claude Code 插件

```bash
claude plugin add niaka3dayo/agent-skills-vrc-udon
```

### 方式三：npx 直接安装

```bash
npx agent-skills-vrc-udon
```

选项：

```bash
npx agent-skills-vrc-udon --force    # 覆盖已有文件
npx agent-skills-vrc-udon --list     # 预览待安装文件（模拟运行）
```

### 方式四：git clone

```bash
git clone https://github.com/niaka3dayo/agent-skills-vrc-udon.git
```

---

<h2 id="structure">项目结构</h2>

```text
skills/                                  # 所有技能
  unity-vrc-udon-sharp/                 # UdonSharp 核心技能
    SKILL.md                              # 技能定义 + frontmatter
    LICENSE.txt                           # MIT 许可证
    CHEATSHEET.md                         # 速查表（1 页）
    rules/                               # 约束规则
      udonsharp-constraints.md
      udonsharp-networking.md
      udonsharp-sync-selection.md
    hooks/                               # PostToolUse 验证
      validate-udonsharp.sh
      validate-udonsharp.ps1
    assets/templates/                    # 代码模板（4 个文件）
    references/                          # 详细文档（11 个文件）
  unity-vrc-world-sdk-3/                # VRC World SDK 技能
    SKILL.md, LICENSE.txt, CHEATSHEET.md, references/（7 个文件）
templates/                               # AI 工具配置模板
  CLAUDE.md  AGENTS.md  GEMINI.md        # 通过安装器分发给用户
.claude-plugin/marketplace.json         # Claude Code 插件注册
CLAUDE.md                               # 开发指南（仅限本仓库）
```

---

<h2 id="skills">技能</h2>

### unity-vrc-udon-sharp

UdonSharp 脚本核心技能。涵盖编译约束、网络同步、事件和模板。

| 领域 | 内容 |
|------|------|
| **约束** | 被禁用的 C# 特性及替代方案（`List<T>` &rarr; `DataList`、`async` &rarr; `SendCustomEventDelayedSeconds`） |
| **网络同步** | Ownership 模型、Manual/Continuous 同步、FieldChangeCallback、反模式 |
| **NetworkCallable** | SDK 3.8.1+ 参数化网络事件（最多 8 个参数） |
| **持久化** | SDK 3.7.4+ PlayerData/PlayerObject API |
| **动态组件** | SDK 3.10.0+ PhysBones、Contacts、VRC Constraints for Worlds |
| **网络加载** | String/Image 下载、VRCJson、VRCUrl 约束 |
| **模板** | 4 个入门模板（BasicInteraction、SyncedObject、PlayerSettings、CustomInspector） |

### unity-vrc-world-sdk-3

世界级别的场景设置、组件配置和性能优化。

| 领域 | 内容 |
|------|------|
| **场景设置** | VRC_SceneDescriptor、出生点、Reference Camera |
| **组件** | VRC_Pickup、Station、ObjectSync、Mirror、Portal、CameraDolly |
| **层级** | VRChat 预留层和碰撞矩阵 |
| **性能** | FPS 目标、Quest/Android 限制、优化清单 |
| **光照** | 烘焙光照最佳实践 |
| **音频/视频** | 空间音频、视频播放器选择（AVPro vs Unity） |
| **上传** | 构建和上传流程、上传前检查清单 |

---

<h2 id="rules">规则</h2>

规则是在 AI 代理生成代码之前对其进行引导的约束文件。

| 规则文件 | 内容 |
|----------|------|
| `udonsharp-constraints` | 被禁用的 C# 特性、代码生成规则、特性标注、可同步类型 |
| `udonsharp-networking` | Ownership 模型、同步模式、反模式、NetworkCallable 约束 |
| `udonsharp-sync-selection` | 同步决策树、数据预算目标、6 条最小化原则 |

### 同步决策树

```text
Q1: 其他玩家需要看到吗？
    否  --> 无需同步（0 字节）
    是  --> Q2

Q2: 后加入者需要获取当前状态吗？
    否  --> 仅使用事件（0 字节）
    是  --> Q3

Q3: 是否持续变化？（位置/旋转）
    是  --> Continuous 同步
    否  --> Manual 同步（最少量的 [UdonSynced]）
```

**目标**：每个 Behaviour < 50 字节。中小型世界：总计 < 100 字节。

---

<h2 id="hooks">验证钩子</h2>

在编辑 `.cs` 文件时自动运行的 PostToolUse 钩子。

| 类别 | 检查项 | 严重级别 |
|------|--------|----------|
| 被禁用的特性 | `List<T>`、`async/await`、`try/catch`、LINQ、协程、lambda 表达式 | ERROR |
| 被禁用的模式 | `AddListener()`、`StartCoroutine()` | ERROR |
| 网络同步 | `[UdonSynced]` 缺少 `RequestSerialization()` | WARNING |
| 网络同步 | `[UdonSynced]` 缺少 `Networking.SetOwner()` | WARNING |
| 同步膨胀 | 单个 Behaviour 中同步变量超过 6 个 | WARNING |
| 同步膨胀 | 同步 `int[]`/`float[]`（建议使用更小的类型） | WARNING |
| 配置冲突 | `NoVariableSync` 模式下使用了 `[UdonSynced]` 字段 | ERROR |

同时支持 **Bash**（`validate-udonsharp.sh`）和 **PowerShell**（`validate-udonsharp.ps1`）。

---

## SDK 版本

| SDK 版本 | 主要特性 | 状态 |
|:--------:|:---------|:----:|
| **3.7.1** | `StringBuilder`、`Regex`、`System.Random` | 已支持 |
| **3.7.4** | Persistence API（PlayerData / PlayerObject） | 已支持 |
| **3.7.6** | 多平台构建与发布（PC + Android） | 已支持 |
| **3.8.0** | PhysBone 依赖排序、Force Kinematic On Remote | 已支持 |
| **3.8.1** | `[NetworkCallable]` 参数化事件、`Others`/`Self` 目标 | 已支持 |
| **3.9.0** | Camera Dolly API、Auto Hold 拾取 | 已支持 |
| **3.10.0** | VRChat Dynamics for Worlds（PhysBones、Contacts、VRC Constraints） | 已支持 |
| **3.10.1** | Bug 修复、稳定性改进 | 已支持 |
| **3.10.2** | EventTiming.PostLateUpdate/FixedUpdate、PhysBones 修复、着色器时间全局变量 | 最新稳定版 |

> **注意**：SDK < 3.9.0 已于 2025 年 12 月 2 日弃用。上传新世界需要 3.9.0+。

---

## 官方资源

| 资源 | 链接 |
|------|------|
| VRChat 创作者文档 | https://creators.vrchat.com/ |
| UdonSharp API 参考 | https://udonsharp.docs.vrchat.com/ |
| VRChat 论坛（问答） | https://ask.vrchat.com/ |
| VRChat Canny（Bug/功能请求） | https://feedback.vrchat.com/ |
| VRChat 社区 GitHub | https://github.com/vrchat-community |

---

<h2 id="contributing">参与贡献</h2>

**欢迎提交 Issues** -- Bug 报告和知识请求有助于改进本项目。

**不接受 Pull Request** -- 所有修复和更新均由维护者完成。

详情请参阅 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

<h2 id="disclaimer">免责声明</h2>

> **本项目与 VRChat Inc. 无关。不存在任何官方认可、合作或关联关系。**
>
> "VRChat"、"UdonSharp"、"Udon" 及相关名称/标识是 VRChat Inc. 的商标。所有商标归其各自所有者所有。
>
> 本仓库是一个**个人知识库**，旨在帮助 AI 编码代理生成正确的 UdonSharp 代码。不分发 VRChat SDK 或 UdonSharp 编译器的任何部分。

### 准确性

- 内容以 **"按原样"（AS IS）** 提供，不附带任何保证。请参阅 [LICENSE](LICENSE)。
- 这是一个个人项目。**可能存在错误、过时信息或不完整的内容。** 请始终以 [VRChat 官方文档](https://creators.vrchat.com/) 为准进行验证。
- 作者不对因使用本仓库而导致的任何问题（构建错误、上传被拒、意外的世界行为等）承担责任。
- SDK 覆盖范围（3.7.1 - 3.10.2）反映最后一次更新的状态。VRChat 新版本发布后，行为可能会发生变化。

### AI 辅助创建

本知识库在 AI 工具（Claude、Gemini、Codex）的辅助下创建和维护。所有内容均已经过审核，但 AI 生成的部分可能包含细微错误。使用风险自负。

---

## 许可证

本项目采用 **MIT 许可证** 授权。详情请参阅 [LICENSE](LICENSE)。

你可以在 MIT 许可证条款下自由地 fork、修改和再分发。此许可证适用于本仓库中的文档、规则、模板和钩子，**不**授予对 VRChat SDK、UdonSharp 编译器或其他 VRChat 知识产权的任何权利。
