# 同期パターン選択 (常時ロード)

コード生成前に必ず参照。WHAT (何を同期するか) と WHEN (いつ同期すべきか) の判断フレームワーク。
実践パターンとコード例は `../references/sync-examples.md` を参照。

## デシジョンツリー

```
Q1: 他プレイヤーに見える必要があるか?
  No  → No sync ([UdonSynced] なし, NoVariableSync)
  Yes → Q2

Q2: Late Joiner が途中参加しても現在の状態を知る必要があるか?
  No  → SendCustomNetworkEvent のみ (synced 変数不要)
  Yes → Q3

Q3: 値が連続的に変化するか? (位置・回転)
  Yes → Continuous sync
  No  → Manual sync + 最小限の [UdonSynced]
```

| ユースケース | パターン | synced 変数 | 例 |
|-------------|---------|------------|-----|
| 個人エフェクト | No sync | 0 | 銃の発射パーティクル |
| 全員で一時的アクション | Events only | 0 | 効果音・アニメ再生 |
| 永続する共有状態 | Manual sync | 最小限 | スコア・ゲーム進行 |
| 連続追従 (位置・回転) | Continuous | 位置系のみ | オブジェクト移動 |

## データバジェット

コード生成前に synced データ量を見積もること。

| Type | Bytes | 用途 |
|------|-------|------|
| `bool` | 1 | フラグ |
| `byte` | 1 | 0-255 の小さい値 |
| `short` | 2 | 0-65535 |
| `int` | 4 | 汎用整数 |
| `float` | 4 | 小数 |
| `Vector3` | 12 | 位置 |
| `Quaternion` | 16 | 回転 |
| `string` | ~50B上限 | テキスト (短く保つ) |

**目標**: 1 behaviour あたり < 50 bytes

**参考値** (典型的なワールドギミック):
- 投票システム: `int + int + bool` = **9 bytes**
- シューティング管理: `bool + bool + string + int` = **~38 bytes**
- グローバルカウンター: synced 変数 **0** (SendCustomNetworkEvent のみ)
- 小〜中規模ワールドの合計: **100 bytes 未満** が一般的

**帯域**: 11KB/sec → 1KB ペイロードで ~0.1秒遅延

## 同期最小化 (6 原則)

1. **導出可能な値は同期しない** (経過時間 = 現在時刻 - syncedStartTime)
2. **最小の型を使う** (0-255 → `byte`, 0-65535 → `ushort`)
3. **bool 群はビットパック** (8 flags = `int` 4B vs `bool` x8 = 8B)
4. **一回限りの効果は SendCustomNetworkEvent** (synced 不要)
5. **状態を同期し、アクションは同期しない** (gamePhase を同期、startGame は event)
6. **一元管理** (Owner のみ変更 → OnDeserialization で全員表示更新)

## アンチパターン: Sync Bloat (同期肥大化)

| NG パターン | 改善策 |
|------------|--------|
| 表示用の値を同期 | ソースデータのみ同期、表示はローカル計算 |
| `byte` で足りる値に `int` を使用 | 型サイズを意識して最小型を選択 |
| プレイヤー個別データを共有オブジェクトに同期 | PlayerData API (SDK 3.7.4+) を検討 |
| 全変数を `[UdonSynced]` にする | Late Joiner が本当に必要とする値のみ |
| 状態 + アクション両方を同期 | 状態のみ同期、アクションは event |
