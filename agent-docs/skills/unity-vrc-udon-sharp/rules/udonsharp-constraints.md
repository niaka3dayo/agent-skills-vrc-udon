# UdonSharp コンパイル制約 (常時ロード)

UdonSharp は C# から Udon Assembly へコンパイルする。標準 C# と異なる制約を常に遵守すること。

**SDK対応**: 3.7.1 - 3.10.1 (2026年2月時点)

## ブロック機能

| 機能 | 代替手段 |
|------|---------|
| `List<T>`, `Dictionary<T,K>` | `T[]` 配列 or `DataList`/`DataDictionary` (VRC.SDK3.Data) |
| `HashSet<T>`, `Queue<T>`, `Stack<T>` | 配列で実装 |
| Generic type parameters | 具象型を使用 |
| `interface` | 基底クラス継承 or `SendCustomEvent` |
| Method overloading | 一意なメソッド名 (`DoInt`, `DoString`) |
| Operator overloading | 明示的メソッド |
| `try`/`catch`/`finally`/`throw` | 防御的 null チェック + 早期 return |
| `async`/`await` | `SendCustomEventDelayedSeconds()` |
| `yield return` (coroutines) | `SendCustomEventDelayedSeconds()` |
| `StartCoroutine()` | `SendCustomEventDelayedSeconds()` |
| Delegates / C# events | `SendCustomEvent` |
| `Button.onClick.AddListener()` | Inspector で SendCustomEvent を設定 |
| LINQ (`.Where`, `.Select` 等) | 手動 for ループ |
| Lambda expressions | 名前付きメソッド |
| Local functions | private メソッド |
| Pattern matching | 従来の `if`/`switch` |
| Anonymous types | 明示的な型定義 |
| `System.IO`, `System.Net` | `VRCStringDownloader`, `VRCImageDownloader` |
| `System.Reflection` | 利用不可 |
| `System.Threading` | 利用不可 |
| `unsafe`, pointers | 利用不可 |

## 利用可能な機能 (SDK 3.7.1+)

| 機能 | 備考 |
|------|------|
| `System.Text.StringBuilder` | 効率的な文字列連結 |
| `System.Text.RegularExpressions` | Regex パターンマッチング |
| `System.Random` | シード付き決定性乱数 |
| `System.Type` | ランタイム型情報 |
| `GetComponent<T>()` (継承) | UdonSharpBehaviour 継承型で動作 (SDK 3.8+) |

## コード生成ルール

### 1. クラス宣言

必ず `UdonSharpBehaviour` を継承。`MonoBehaviour` 禁止。

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class MyScript : UdonSharpBehaviour { }
```

### 2. フィールド初期化

フィールド初期化子はコンパイル時評価。シーン依存の参照は `Start()` / Lazy Init で取得。

```csharp
// OK: コンパイル時定数
private int maxPlayers = 10;

// NG: ランタイム値をフィールド初期化子に書く
// private int rng = Random.Range(0, 100); // 全インスタンスで同じ値!

// OK: Start() で初期化
private int rng;
void Start() { rng = Random.Range(0, 100); }
```

**Lazy Initialization パターン** (非アクティブオブジェクト対策):

```csharp
private Transform _target;
private bool _init;

private void EnsureInit()
{
    if (_init) return;
    var go = GameObject.Find("Target");
    if (go != null) _target = go.transform;
    _init = true;
}
```

### 3. 構造体のミューテーション

構造体のミューテーションメソッドは元の値を変更しない。戻り値を使う。

```csharp
// NG: v は変わらない
Vector3 v = new Vector3(3, 4, 0);
v.Normalize();

// OK: 戻り値を代入
v = v.normalized;
```

### 4. GetComponent の制限

`GetComponent<UdonBehaviour>()` は未公開。キャスト構文を使う。

```csharp
// NG
UdonBehaviour ub = GetComponent<UdonBehaviour>();

// OK
UdonBehaviour ub = (UdonBehaviour)GetComponent(typeof(UdonBehaviour));

// OK (SDK 3.8+): UdonSharpBehaviour 継承型は Generic で取得可能
MyScript s = GetComponent<MyScript>();
```

### 5. アクセス修飾子

`private` メソッド推奨。public メソッドは Udon のメソッドルックアップを遅くする。

### 6. 再帰メソッド

再帰呼び出しには `[RecursiveMethod]` 属性が必須。

```csharp
[RecursiveMethod]
private int Factorial(int n)
{
    if (n <= 1) return 1;
    return n * Factorial(n - 1);
}
```

### 7. uGUI ボタンイベントと Unity コールバック

- `Button.onClick.AddListener()` 不可 → Inspector の OnClick で SendCustomEvent を設定
- Unity コールバック (`OnTriggerEnter` 等) に `override` は**不要** → `override` は VRChat イベントのみ

```csharp
// NG: override → CS0115 エラー
public override void OnTriggerEnter(Collider other) { }
// OK: override なし
public void OnTriggerEnter(Collider other) { }
// OK: VRChat イベントは override 必要
public override void OnPlayerJoined(VRCPlayerApi player) { }
```

## 属性クイックリファレンス

### クラスレベル

| 属性 | 用途 |
|------|------|
| `[UdonBehaviourSyncMode(mode)]` | 同期モード指定 |
| `[DefaultExecutionOrder(n)]` | 実行順序制御 |

### フィールドレベル

| 属性 | 用途 |
|------|------|
| `[UdonSynced]` | フィールド同期 |
| `[UdonSynced(UdonSyncMode.Linear)]` | 線形補間 (位置/回転) |
| `[UdonSynced(UdonSyncMode.Smooth)]` | スムース補間 |
| `[FieldChangeCallback(nameof(Prop))]` | 変更時プロパティ setter 呼び出し |

### メソッドレベル

| 属性 | 用途 |
|------|------|
| `[RecursiveMethod]` | 再帰呼び出し許可 |
| `[NetworkCallable]` | ネットワークイベント (SDK 3.8.1+) |

## 同期可能な型

`[UdonSynced]` で同期可能な型:

`bool`, `byte`, `sbyte`, `char`, `short`, `ushort`, `int`, `uint`, `long`, `ulong`,
`float`, `double`, `string` (~50文字制限), `Vector2`, `Vector3`, `Vector4`,
`Quaternion`, `Color`, `Color32`, `T[]` (上記型の配列)

## DataList / DataDictionary

```csharp
using VRC.SDK3.Data;

// List<string> の代替
DataList list = new DataList();
list.Add("a");
string first = list[0].String;

// Dictionary<string, int> の代替
DataDictionary dict = new DataDictionary();
dict["key"] = 100;
int val = dict["key"].Int;
```

## バリデーションチェックリスト

- [ ] `List<T>` / `Dictionary<T,K>` を使っていないか
- [ ] `interface` 宣言がないか
- [ ] メソッドオーバーロードがないか (全メソッド名が一意か)
- [ ] `try`/`catch` がないか
- [ ] `async`/`await` / `yield return` がないか
- [ ] LINQ / Lambda がないか
- [ ] `System.IO` / `System.Net` がないか
- [ ] 再帰メソッドに `[RecursiveMethod]` があるか
- [ ] 構造体メソッドで戻り値を使っているか
- [ ] `AddListener()` を使っていないか
- [ ] Unity コールバック (OnTriggerEnter 等) に override を付けていないか
