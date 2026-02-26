# VRChat ワールドトラブルシューティングガイド

ワールド開発でよく遭遇する問題と解決策。

## 目次

- [Build & Upload Issues](#build--upload-issues)
- [Scene Setup Issues](#scene-setup-issues)
- [Component Issues](#component-issues)
- [Layer & Collision Issues](#layer--collision-issues)
- [Performance Issues](#performance-issues)
- [Networking Issues](#networking-issues)
- [Quest/Android Issues](#questandroid-issues)
- [Investigation Steps](#investigation-steps)

---

## ビルド & アップロードの問題

### "Missing VRC_SceneDescriptor"

**症状**: ビルド時に SceneDescriptor がないというエラー

**解決策**:
```
1. VRChat SDK > Show Control Panel
2. Builder タブ
3. "Add VRChat World" または VRCWorld Prefab を追加
4. シーンに 1 つだけ存在することを確認
```

### "Layer collision matrix needs setup"

**症状**: レイヤー設定が正しくないという警告

**解決策**:
```text
1. VRChat SDK > Show Control Panel
2. Builder タブ
3. "Setup Layers for VRChat" をクリック
4. 自動的にレイヤーとコリジョンマトリックスが設定される
```

### Upload 後にワールドが見つからない

**症状**: アップロード成功したがワールドが表示されない

**解決策**:
```
1. VRChat ウェブサイトにログイン
2. "My Worlds" を確認
3. 非公開設定を確認
4. 数分待つ（反映に時間がかかる場合あり）
5. VRChat クライアントを再起動
```

### "Build was cancelled"

**症状**: ビルドがキャンセルされた

**解決策**:
```
1. Unity Console でエラーを確認
2. スクリプトコンパイルエラーを解決
3. Missing Reference を解決
4. 再度ビルド
```

---

## シーンセットアップの問題

### プレイヤーがスポーン地点に出現しない

**症状**: 参加時に予期しない場所に出現

**解決策**:
```
1. VRC_SceneDescriptor の Spawns 配列を確認
2. Spawns に有効な Transform が設定されているか確認
3. Spawn 位置が障害物の中にないか確認
4. Spawn の Y 座標が Respawn Height より上か確認
```

### プレイヤーが無限にリスポーンする

**症状**: 参加直後にリスポーンを繰り返す

**解決策**:
```
1. Respawn Height を確認
2. Spawn 位置が Respawn Height より上にあることを確認
3. Spawn 位置が床の下にないか確認
4. Respawn Height を十分低く設定 (例: -100)
```

### Reference Camera が反映されない

**症状**: カメラ設定が適用されない

**解決策**:
```
1. Reference Camera の Camera コンポーネントが無効化されているか確認
2. SceneDescriptor の Reference Camera フィールドに正しく設定
3. Post Processing の場合、Volume も確認
```

---

## コンポーネントの問題

### VRC_Pickup が持てない

**症状**: オブジェクトをインタラクトできない、持てない

**解決策**:
```text
1. Collider が存在するか確認
2. Rigidbody が存在するか確認
3. VRC_Pickup の Pickupable が true か確認
4. レイヤーが正しいか確認 (Pickup layer 推奨)
5. Collider が有効か確認
```

### VRC_Pickup が同期しない

**症状**: 持ったオブジェクトが他プレイヤーに見えない

**解決策**:
```
1. VRC_ObjectSync コンポーネントを追加
2. Rigidbody が存在するか確認
3. Is Kinematic の設定を確認
```

### VRC_Pickup を離せない

**症状**: 持ったオブジェクトを離せない

**解決策**:
```
1. Auto Hold 設定を確認 (SDK 3.9+)
2. Udon スクリプトで Drop を阻害していないか確認
3. VRC_Pickup コンポーネントを再追加
```

### VRC_Station に座れない

**症状**: Station をインタラクトできない

**解決策**:
```
1. Collider が存在するか確認
2. VRC_Station の Disable Station Exit が false か確認
3. Udon で UseAttachedStation() を呼んでいる場合、
   そのスクリプトが Station と同じオブジェクトにあるか確認
```

### VRC_Station から降りられない

**症状**: 座った後に降りられない

**解決策**:
```
1. Disable Station Exit が true なら false に
2. Exit Transform が障害物の中にないか確認
3. Udon で強制退出を実装
```

### VRC_Mirror が映らない

**症状**: ミラーに何も表示されない

**解決策**:
```
1. MirrorReflection レイヤー設定を確認
2. ミラーが有効か確認
3. カメラの Near/Far Clip を確認
4. ミラー解像度を確認
```

### VRC_ObjectSync がずれる

**症状**: 同期オブジェクトの位置が他プレイヤーとずれる

**解決策**:
```
1. FlagDiscontinuity() を瞬間移動時に呼ぶ
2. Allow Collision Ownership Transfer 設定を確認
3. 頻繁な所有権移転を避ける
```

---

## レイヤーとコリジョンの問題

### プレイヤーが壁を通り抜ける

**症状**: 壁やオブジェクトをすり抜ける

**解決策**:
```
1. 壁を Environment レイヤーに設定
2. Collider が存在するか確認
3. Collider の Is Trigger が false か確認
4. Collision Matrix で Player と Environment が衝突するか確認
```

### Pickup が床を通り抜ける

**症状**: 落としたオブジェクトが床を通り抜ける

**解決策**:
```text
1. Pickup を Pickup レイヤーに設定
2. 床を Environment レイヤーに設定
3. Collision Matrix で Pickup と Environment が衝突するか確認
4. Rigidbody の Collision Detection を Continuous に
```

### オブジェクトがミラーに映らない

**症状**: 特定のオブジェクトだけミラーに映らない

**解決策**:
```
1. オブジェクトのレイヤーを確認
2. MirrorReflection レイヤーとの関係を確認
3. オブジェクトの Renderer が有効か確認
```

---

## パフォーマンスの問題

### FPS が低い

**症状**: フレームレートが低い

**解決策**:
```text
1. ミラーをデフォルト OFF にする
2. リアルタイムライトを削減/削除
3. ライトをベイク
4. ビデオプレイヤー数を確認 (2つまで)
5. Draw Call を削減
6. ポリゴン数を削減
7. テクスチャ解像度を下げる
```

### ミラーが重い

**症状**: ミラー有効時に FPS が激減

**解決策**:
```
1. ミラー解像度を下げる
2. ミラー数を 1 つに制限
3. デフォルト OFF にして切り替え式に
4. 距離で自動無効化を実装
```

### ライティングが重い

**症状**: ライト周辺で FPS が低下

**解決策**:
```
1. リアルタイムライトを削除
2. Mixed または Baked に変更
3. ライトマップをベイク
4. Light Probes を配置
5. シャドウ品質を下げる
```

---

## ネットワーキングの問題

### オブジェクトの所有権が移転しない

**症状**: SetOwner が機能しない

**解決策**:
```csharp
// 正しい呼び出し:
Networking.SetOwner(Networking.LocalPlayer, gameObject);

// VRC_ObjectSync がある場合:
// Allow Collision Ownership Transfer 設定を確認
```

### Late Joiner に状態が同期しない

**症状**: 後から参加したプレイヤーに状態が反映されない

**解決策**:
```csharp
// OnDeserialization で状態を適用
public override void OnDeserialization()
{
    ApplyState();
}

// VRC_ObjectSync の場合は自動同期
// Udon 変数の場合は [UdonSynced] 属性を使用
```

---

## Quest/Android の問題

### Quest でワールドが表示されない

**症状**: PC では動くが Quest で動かない

**解決策**:
```text
1. Android ビルドターゲットで確認
2. シェーダーを Mobile 対応に変更
3. Dynamic Bones を削除 (Quest では無効)
4. Cloth を削除 (Quest では無効)
5. Post Processing を削除 (Quest では無効)
6. ポリゴン数を削減 (100K以下推奨)
```

### Quest でパフォーマンスが悪い

**症状**: Quest で FPS が低い

**解決策**:
```text
1. ポリゴン数: 100K 以下
2. マテリアル数: 25 以下
3. テクスチャ: 1024x1024 以下
4. ライト: 完全ベイク
5. シェーダー: Mobile/VRChat/Lightmapped
6. 透明度を最小限に
7. ミラーを削除または極小に
```

---

## 調査手順

### 未知のエラー調査手順

#### 手順 1: Unity Console 確認

```
Window > General > Console
- エラー (赤) を優先的に確認
- 警告 (黄) も確認
- スタックトレースで発生箇所を特定
```

#### 手順 2: VRChat SDK バリデーション

```
VRChat SDK > Show Control Panel
Builder タブ > Validations セクション
- 自動修正可能な問題はボタンで修正
- 手動修正が必要な問題は指示に従う
```

#### 手順 3: ビルドとテスト

```text
VRChat SDK > Show Control Panel
Builder タブ > "Build & Test New Build"
- Number of Clients で複数プレイヤーテスト
- VRChat 内でデバッグ情報を確認
```

#### 手順 4: 公式ドキュメント検索 (WebSearch)

```
WebSearch: "エラーメッセージやキーワード site:creators.vrchat.com"
```

#### 手順 5: VRChat Forums 検索 (WebSearch)

```
WebSearch:
  query: "エラーメッセージ site:ask.vrchat.com"
  allowed_domains: ["ask.vrchat.com"]
```

#### 手順 6: Canny (既知のバグ) 検索

```
WebSearch:
  query: "問題 site:feedback.vrchat.com"
  allowed_domains: ["feedback.vrchat.com"]
```

#### 手順 7: GitHub Issues 検索

```
WebSearch:
  query: "問題 site:github.com/vrchat-community"
  allowed_domains: ["github.com"]
```

---

## クイックリファレンス: エラー → 解決策

| エラー/問題 | 解決策 |
|------------|--------|
| Missing SceneDescriptor | VRCWorld Prefab を追加 |
| Layer Matrix 警告 | "Setup Layers for VRChat" |
| Pickup 持てない | Collider + Rigidbody 追加 |
| Pickup 同期しない | VRC_ObjectSync 追加 |
| Station 座れない | Collider 追加 |
| Mirror 映らない | レイヤー確認 |
| 壁すり抜け | Environment レイヤー |
| FPS 低い | ミラーOFF、ライトベイク |
| Quest で動かない | Mobile シェーダー使用 |
| Late Joiner 同期 | OnDeserialization で適用 |

---

## リソース

- [VRChat Creators](https://creators.vrchat.com/worlds/)
- [VRChat Forums](https://ask.vrchat.com/)
- [VRChat Canny](https://feedback.vrchat.com/)
- [SDK Release Notes](https://creators.vrchat.com/releases/)
