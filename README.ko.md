[English](README.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | **한국어**

<p align="center">
  <img src="https://img.shields.io/badge/VRChat_SDK-3.7.1--3.10.2-00b4d8?style=for-the-badge" alt="VRChat SDK" />
  <img src="https://img.shields.io/badge/UdonSharp-C%23_%E2%86%92_Udon-5C2D91?style=for-the-badge&logo=csharp&logoColor=white" alt="UdonSharp" />
  <img src="https://img.shields.io/badge/AI_Agent-Skills_%26_Rules-ff6b35?style=for-the-badge" alt="에이전트 스킬" />
  <img src="https://img.shields.io/github/license/niaka3dayo/agent-skills-vrc-udon?style=for-the-badge" alt="라이선스" />
</p>

<p align="center">
  <img src="https://img.shields.io/npm/v/agent-skills-vrc-udon?style=flat-square&label=npm" alt="npm 버전" />
  <img src="https://img.shields.io/npm/dm/agent-skills-vrc-udon?style=flat-square&label=downloads" alt="npm 다운로드" />
  <img src="https://img.shields.io/github/actions/workflow/status/niaka3dayo/agent-skills-vrc-udon/ci.yml?branch=dev&style=flat-square&label=CI" alt="CI" />
</p>

<h1 align="center">Agent Skills for VRChat UdonSharp</h1>

<p align="center">
  <b>AI 코딩 에이전트가 올바른 UdonSharp 코드를 생성하도록 돕는 스킬, 규칙, 검증 훅</b>
</p>

<p align="center">
  <a href="#about">소개</a> &bull;
  <a href="#install">설치</a> &bull;
  <a href="#structure">구조</a> &bull;
  <a href="#skills">스킬</a> &bull;
  <a href="#rules">규칙</a> &bull;
  <a href="#hooks">훅</a> &bull;
  <a href="#contributing">기여</a> &bull;
  <a href="#disclaimer">면책 조항</a>
</p>

---

<h2 id="about">소개</h2>

**UdonSharp**(C# → Udon Assembly)을 사용한 VRChat 월드 개발에는 일반 C#과 크게 다른 엄격한 컴파일 제약이 있습니다. `List<T>`, `async/await`, `try/catch`, LINQ, 람다 등의 기능을 사용하면 **컴파일 오류**가 발생합니다.

이 리포지토리는 AI 코딩 에이전트가 처음부터 올바른 UdonSharp 코드를 생성할 수 있도록 필요한 지식을 제공합니다.

| 문제 | 해결 방안 |
|------|-----------|
| AI가 `List<T>`, `async/await` 등을 생성함 | 규칙 + 훅이 자동 감지 및 경고 |
| 동기화 변수 비대화 | 의사 결정 트리 + 데이터 예산 |
| 잘못된 네트워킹 패턴 | 패턴 라이브러리 + 안티패턴 |
| SDK 버전별 기능 차이 | 기능 매핑이 포함된 버전 테이블 |
| Late Joiner 상태 불일치 | 동기화 패턴 선택 프레임워크 |

**이 프로젝트는 다음이 아닙니다:**
- VRChat SDK 또는 UdonSharp 배포판
- Unity 프로젝트 (실행 가능한 코드 없음)
- [공식 VRChat 문서](https://creators.vrchat.com/)의 대체품
- 모든 AI 동작에 대한 보증

> **이슈**: 버그 리포트와 지식 요청은 [GitHub Issues](https://github.com/niaka3dayo/agent-skills-vrc-udon/issues)를 통해 언제든 환영합니다.
> **PR**: Pull Request는 받지 않습니다. 자세한 내용은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참조하세요.

---

<h2 id="install">설치</h2>

> **fork/clone에서 마이그레이션하시나요?** — v1.0.0부터 이 프로젝트는 **npm 패키지**로 배포됩니다. 더 이상 리포지토리를 fork하거나 clone할 필요가 없습니다. VRChat Unity 프로젝트 내에서 아래 설치 명령 중 하나를 실행하세요. 이전에 이 리포지토리를 clone한 경우, clone된 디렉터리를 삭제하고 npm 기반 설치로 전환해도 안전합니다.

### 방법 1: skills CLI (권장)

```bash
npx skills add niaka3dayo/agent-skills-vrc-udon
```

[skills.sh](https://skills.sh) 생태계를 사용하여 프로젝트에 스킬을 설치합니다.

### 방법 2: Claude Code 플러그인

```bash
claude plugin add niaka3dayo/agent-skills-vrc-udon
```

### 방법 3: npx 직접 설치

```bash
npx agent-skills-vrc-udon
```

옵션:

```bash
npx agent-skills-vrc-udon --force    # 기존 파일 덮어쓰기
npx agent-skills-vrc-udon --list     # 설치될 파일 미리보기 (드라이런)
```

### 방법 4: git clone

```bash
git clone https://github.com/niaka3dayo/agent-skills-vrc-udon.git
```

---

<h2 id="structure">구조</h2>

```text
skills/                                  # 모든 스킬
  unity-vrc-udon-sharp/                 # UdonSharp 핵심 스킬
    SKILL.md                              # 스킬 정의 + 프론트매터
    LICENSE.txt                           # MIT License
    CHEATSHEET.md                         # 빠른 참조 (1페이지)
    rules/                               # 제약 규칙
      udonsharp-constraints.md
      udonsharp-networking.md
      udonsharp-sync-selection.md
    hooks/                               # PostToolUse 검증
      validate-udonsharp.sh
      validate-udonsharp.ps1
    assets/templates/                    # 코드 템플릿 (4개 파일)
    references/                          # 상세 문서 (19개 파일)
  unity-vrc-world-sdk-3/                # VRC World SDK 스킬
    SKILL.md, LICENSE.txt, CHEATSHEET.md, references/ (7개 파일)
templates/                               # AI 도구 설정 템플릿
  CLAUDE.md  AGENTS.md  GEMINI.md        # 인스톨러를 통해 사용자에게 배포
.claude-plugin/marketplace.json         # Claude Code 플러그인 등록
CLAUDE.md                               # 개발 가이드 (이 리포지토리 전용)
```

---

<h2 id="skills">스킬</h2>

### unity-vrc-udon-sharp

UdonSharp 스크립팅 핵심 스킬. 컴파일 제약, 네트워킹, 이벤트, 템플릿을 다룹니다.

| 영역 | 내용 |
|------|------|
| **제약** | 차단된 C# 기능과 대안 (`List<T>` → `DataList`, `async` → `SendCustomEventDelayedSeconds`) |
| **네트워킹** | Ownership 모델, Manual/Continuous 동기화, FieldChangeCallback, 안티패턴 |
| **NetworkCallable** | SDK 3.8.1+ 매개변수화된 네트워크 이벤트 (최대 8개 인수) |
| **Persistence** | SDK 3.7.4+ PlayerData/PlayerObject API |
| **Dynamics** | SDK 3.10.0+ PhysBones, Contacts, VRC Constraints for Worlds |
| **웹 로딩** | String/Image 다운로드, VRCJson, VRCUrl 제약 |
| **템플릿** | 4개의 스타터 템플릿 (BasicInteraction, SyncedObject, PlayerSettings, CustomInspector) |

### unity-vrc-world-sdk-3

월드 레벨의 씬 설정, 컴포넌트 배치, 최적화.

| 영역 | 내용 |
|------|------|
| **씬 설정** | VRC_SceneDescriptor, 스폰 포인트, Reference Camera |
| **컴포넌트** | VRC_Pickup, Station, ObjectSync, Mirror, Portal, CameraDolly |
| **레이어** | VRChat 예약 레이어 및 충돌 매트릭스 |
| **퍼포먼스** | FPS 목표, Quest/Android 제한, 최적화 체크리스트 |
| **라이팅** | 베이크드 라이팅 모범 사례 |
| **오디오/비디오** | 공간 오디오, 비디오 플레이어 선택 (AVPro vs Unity) |
| **업로드** | 빌드 및 업로드 워크플로, 업로드 전 체크리스트 |

---

<h2 id="rules">규칙</h2>

규칙은 코드 생성 전에 AI 에이전트를 안내하는 제약 파일입니다.

| 규칙 파일 | 내용 |
|-----------|------|
| `udonsharp-constraints` | 차단된 C# 기능, 코드 생성 규칙, 어트리뷰트, 동기화 가능 타입 |
| `udonsharp-networking` | Ownership 모델, 동기화 모드, 안티패턴, NetworkCallable 제약 |
| `udonsharp-sync-selection` | 동기화 의사 결정 트리, 데이터 예산 목표, 6가지 최소화 원칙 |

### 동기화 의사 결정 트리

```text
Q1: 다른 플레이어에게 보여야 하나요?
    아니오 --> 동기화 불필요 (0 bytes)
    예    --> Q2

Q2: Late Joiner가 현재 상태를 알아야 하나요?
    아니오 --> 이벤트만 사용 (0 bytes)
    예    --> Q3

Q3: 지속적으로 변하나요? (위치/회전)
    예    --> Continuous sync
    아니오 --> Manual sync (최소한의 [UdonSynced])
```

**목표**: Behaviour당 50 bytes 미만. 소규모~중규모 월드: 총 100 bytes 미만.

---

<h2 id="hooks">검증 훅</h2>

`.cs` 파일 편집 시 자동으로 실행되는 PostToolUse 훅.

| 카테고리 | 검사 항목 | 심각도 |
|----------|-----------|--------|
| 차단된 기능 | `List<T>`, `async/await`, `try/catch`, LINQ, 코루틴, 람다 | ERROR |
| 차단된 패턴 | `AddListener()`, `StartCoroutine()` | ERROR |
| 네트워킹 | `[UdonSynced]` 사용 시 `RequestSerialization()` 누락 | WARNING |
| 네트워킹 | `[UdonSynced]` 사용 시 `Networking.SetOwner()` 누락 | WARNING |
| 동기화 비대화 | Behaviour당 동기화 변수 6개 이상 | WARNING |
| 동기화 비대화 | `int[]`/`float[]` 동기화 (더 작은 타입 권장) | WARNING |
| 설정 불일치 | `NoVariableSync` 모드에서 `[UdonSynced]` 필드 사용 | ERROR |

**Bash** (`validate-udonsharp.sh`)와 **PowerShell** (`validate-udonsharp.ps1`) 모두 지원합니다.

---

## SDK 버전

| SDK 버전 | 주요 기능 | 상태 |
|:--------:|:----------|:----:|
| **3.7.1** | `StringBuilder`, `Regex`, `System.Random` | 지원 |
| **3.7.4** | Persistence API (PlayerData / PlayerObject) | 지원 |
| **3.7.6** | 멀티 플랫폼 빌드 & 퍼블리시 (PC + Android) | 지원 |
| **3.8.0** | PhysBone 종속성 정렬, Force Kinematic On Remote | 지원 |
| **3.8.1** | `[NetworkCallable]` 매개변수화된 이벤트, `Others`/`Self` 타겟 | 지원 |
| **3.9.0** | Camera Dolly API, Auto Hold pickup | 지원 |
| **3.10.0** | VRChat Dynamics for Worlds (PhysBones, Contacts, VRC Constraints) | 지원 |
| **3.10.1** | 버그 수정, 안정성 개선 | 지원 |
| **3.10.2** | EventTiming.PostLateUpdate/FixedUpdate, PhysBones 수정, 셰이더 시간 글로벌 변수 | 최신 안정 버전 |

> **참고**: SDK 3.9.0 미만은 2025년 12월 2일에 지원이 종료되었습니다. 새로운 월드 업로드에는 3.9.0 이상이 필요합니다.

---

## 공식 리소스

| 리소스 | URL |
|--------|-----|
| VRChat Creators Docs | https://creators.vrchat.com/ |
| UdonSharp API Reference | https://udonsharp.docs.vrchat.com/ |
| VRChat Forums (Q&A) | https://ask.vrchat.com/ |
| VRChat Canny (버그/기능 요청) | https://feedback.vrchat.com/ |
| VRChat Community GitHub | https://github.com/vrchat-community |

---

<h2 id="contributing">기여</h2>

**이슈는 언제든 환영합니다** -- 버그 리포트와 지식 요청은 이 프로젝트를 개선하는 데 도움이 됩니다.

**Pull Request는 받지 않습니다** -- 모든 수정과 업데이트는 관리자가 직접 진행합니다.

자세한 내용은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참조하세요.

---

<h2 id="disclaimer">면책 조항</h2>

> **이 프로젝트는 VRChat Inc.와 제휴 관계가 없습니다. 공식적인 지지, 파트너십, 또는 관련성을 의미하지 않습니다.**
>
> "VRChat", "UdonSharp", "Udon" 및 관련 명칭/로고는 VRChat Inc.의 상표입니다. 모든 상표는 해당 소유자에게 귀속됩니다.
>
> 이 리포지토리는 AI 코딩 에이전트가 올바른 UdonSharp 코드를 생성하기 위한 **개인 지식 베이스**입니다. VRChat SDK나 UdonSharp 컴파일러의 어떤 부분도 배포하지 않습니다.

### 정확성

- 콘텐츠는 어떠한 보증 없이 **"있는 그대로"** 제공됩니다. [LICENSE](LICENSE)를 참조하세요.
- 이것은 개인 프로젝트입니다. **오류, 오래된 정보, 불완전한 내용이 있을 수 있습니다.** 반드시 [공식 VRChat 문서](https://creators.vrchat.com/)와 대조하여 확인하세요.
- 이 리포지토리로 인해 발생하는 문제(빌드 오류, 업로드 거부, 예상치 못한 월드 동작 등)에 대해 저자는 어떠한 책임도 지지 않습니다.
- SDK 지원 범위(3.7.1 - 3.10.2)는 마지막 업데이트 시점을 반영합니다. 새로운 VRChat 릴리스에 따라 동작이 변경될 수 있습니다.

### AI 지원 제작

이 지식 베이스는 AI 도구(Claude, Gemini, Codex)의 도움을 받아 작성 및 유지 관리되었습니다. 모든 콘텐츠는 검토를 거쳤으나, AI가 생성한 부분에는 미묘한 오류가 포함될 수 있습니다. 사용에 따른 책임은 본인에게 있습니다.

---

## 라이선스

이 프로젝트는 **MIT License** 하에 제공됩니다. 자세한 내용은 [LICENSE](LICENSE)를 참조하세요.

MIT License 조건에 따라 자유롭게 fork, 수정, 재배포할 수 있습니다. 이 라이선스는 이 리포지토리의 문서, 규칙, 템플릿, 훅에 적용됩니다. VRChat의 SDK, UdonSharp 컴파일러, 기타 VRChat 지적 재산에 대한 어떠한 권리도 부여하지 **않습니다**.
