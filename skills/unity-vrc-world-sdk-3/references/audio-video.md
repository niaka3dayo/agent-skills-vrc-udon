# VRChat オーディオ & ビデオガイド

オーディオとビデオ設定の完全ガイド。

## 目次

- [Audio Overview](#audio-overview)
- [VRC_SpatialAudioSource](#vrc_spatialaudiosource)
- [Voice Settings](#voice-settings)
- [Video Players](#video-players)
- [AVPro vs Unity Video Player](#avpro-vs-unity-video-player)
- [Video Player Setup](#video-player-setup)
- [Optimization](#optimization)
- [Troubleshooting](#troubleshooting)

---

## オーディオ概要

### VRChat のオーディオコンポーネント

| コンポーネント | 目的 | 使用場面 |
|-----------|---------|-------------|
| AudioSource | Unity標準オーディオ | 基本的な音再生 |
| VRC_SpatialAudioSource | VRChat空間オーディオ | 3D定位が必要な音 |
| VoiceSettings | ボイス設定 | VRC_SceneDescriptor で設定 |

### オーディオシステムアーキテクチャ

```
[Audio Source]
├── Unity AudioSource (基本機能)
└── VRC_SpatialAudioSource (拡張機能)
    ├── Gain control
    ├── Near/Far distance
    ├── Volumetric radius
    └── Spatialization options
```

---

## VRC_SpatialAudioSource

### コンポーネント設定

VRC_SpatialAudioSource は Unity AudioSource に追加して使用。

| プロパティ | 型 | 説明 | デフォルト |
|----------|------|-------------|---------|
| **Gain** | float (dB) | 音量増減 (-24 ~ +24) | 0 dB |
| **Near** | float (m) | 減衰開始距離 | 0 m |
| **Far** | float (m) | 減衰終了距離 (0=無限) | 40 m |
| **Volumetric Radius** | float (m) | 音源の広がり | 0 m |
| **Enable Spatialization** | bool | 3D定位有効化 | true |
| **Use AudioSource Volume Curve** | bool | AudioSource カーブ使用 | false |

### 距離減衰モデル

```
Near = 2m, Far = 10m の場合:

距離(m): 0    2    4    6    8    10   12
音量(%): 100  100  75   50   25   0    0
         ←Near→←---減衰---→←Far→

Near = 減衰開始（100%維持）
Far = 減衰終了（0%）
```

### Volumetric Radius

```
Volumetric Radius = 0 (点音源):
- リスナーと音源の距離で計算
- 小さなオブジェクト向け

Volumetric Radius > 0 (体積音源):
- 音源の「表面」からの距離で計算
- 大きなオブジェクト（滝、群衆など）向け
- 例: Radius=5m → 半径5mの球体の表面から減衰開始
```

### 設定例

#### 環境音 (BGM)

```
AudioSource:
├── Spatial Blend: 0 (2D)
├── Loop: true
└── Volume: 0.5

VRC_SpatialAudioSource:
├── Gain: 0 dB
├── Enable Spatialization: false
└── (Near/Farは2D時無視)
```

#### 3D効果音 (足音、ドア)

```
AudioSource:
├── Spatial Blend: 1 (3D)
├── Loop: false
└── Volume: 1.0

VRC_SpatialAudioSource:
├── Gain: 0 dB
├── Near: 1 m
├── Far: 15 m
├── Volumetric Radius: 0
└── Enable Spatialization: true
```

#### 広域音源 (滝、群衆)

```
AudioSource:
├── Spatial Blend: 1 (3D)
├── Loop: true
└── Volume: 1.0

VRC_SpatialAudioSource:
├── Gain: +6 dB (大きめ)
├── Near: 5 m
├── Far: 50 m
├── Volumetric Radius: 10 m
└── Enable Spatialization: true
```

### Udon 制御

```csharp
public class AudioController : UdonSharpBehaviour
{
    [SerializeField] private AudioSource audioSource;
    [SerializeField] private AudioClip[] clips;

    public void PlaySound(int index)
    {
        if (index >= 0 && index < clips.Length)
        {
            audioSource.PlayOneShot(clips[index]);
        }
    }

    public void SetVolume(float volume)
    {
        audioSource.volume = Mathf.Clamp01(volume);
    }

    public void StopSound()
    {
        audioSource.Stop();
    }
}
```

---

## ボイス設定

### VRC_SceneDescriptor ボイスプロパティ

| プロパティ | 型 | 説明 | デフォルト |
|----------|------|-------------|---------|
| **Voice Falloff Range** | float | ボイス減衰範囲 | - |
| **Voice Near** | float | ボイス近距離 | - |
| **Voice Far** | float | ボイス遠距離 | - |
| **Voice Volume** | float | ボイス音量 | - |
| **Voice Disable Lowpass** | bool | ローパス無効 | false |

### Voice Zone (Udon)

```csharp
// プレイヤーのボイス設定を変更
public class VoiceZone : UdonSharpBehaviour
{
    public override void OnPlayerTriggerEnter(VRCPlayerApi player)
    {
        if (player.isLocal)
        {
            // このプレイヤーのボイスが聞こえる範囲を変更
        }
    }
}
```

---

## ビデオプレイヤー

### 種類と特徴

| 機能 | AVPro | Unity Video Player |
|---------|-------|-------------------|
| **ライブストリーム** | ✅ 対応 | ❌ 非対応 |
| **YouTube/Twitch** | ✅ 対応 | ❌ 非対応 |
| **ローカルファイル** | ✅ | ✅ |
| **エディタプレビュー** | ❌ | ✅ |
| **Quest対応** | ✅ | ✅ |
| **HLS/DASH** | ✅ | ❌ |
| **パフォーマンス** | 良好 | 良好 |
| **信頼性** | 高 | 中 |

### 選択ガイド

```
AVPro を使用:
✅ YouTube/Twitch URL を再生したい
✅ ライブストリームを表示したい
✅ 高い信頼性が必要

Unity Video Player を使用:
✅ エディタでプレビューしたい
✅ 単純なローカルファイル再生
✅ 軽量な実装が必要
```

---

## AVPro と Unity Video Player の比較

### AVPro Video Player

```
[Setup]
1. VRChat SDK に含まれる VRCAVProVideoPlayer Prefab を使用
2. または VRC_AVProVideoPlayer コンポーネントを追加

[Features]
├── Supported URLs:
│   ├── YouTube (youtube.com, youtu.be)
│   ├── Twitch (twitch.tv)
│   ├── HLS/DASH streams
│   └── Direct video URLs
│
├── Audio:
│   └── VRC_AVProVideoSpeaker 経由
│
└── Limitations:
    ├── エディタでは再生不可
    └── Quest で一部URLが非対応
```

### Unity Video Player

```
[Setup]
1. VRCUnityVideoPlayer Prefab を使用
2. または VRC_UnityVideoPlayer コンポーネントを追加

[Features]
├── Supported URLs:
│   ├── Direct video URLs (.mp4, .webm)
│   └── ローカルファイル参照
│
├── Audio:
│   └── AudioSource 直接接続
│
└── Advantages:
    ├── エディタでプレビュー可能
    └── シンプルな設定
```

---

## ビデオプレイヤーセットアップ

### AVPro Video Player セットアップ

```
[AVPro Video Player Object]
├── VRC_AVProVideoPlayer
│   ├── Auto Play: false (推奨)
│   ├── Loop: false
│   └── Maximum Resolution: 1080
│
├── Mesh/Quad (スクリーン)
│   └── Material with RenderTexture
│
└── VRC_AVProVideoSpeaker
    ├── AudioSource
    └── VRC_SpatialAudioSource (3D用)
```

### Unity Video Player セットアップ

```
[Unity Video Player Object]
├── VRC_UnityVideoPlayer
│   ├── Auto Play: false (推奨)
│   └── Loop: false
│
├── Mesh/Quad (スクリーン)
│   └── Material with RenderTexture
│
└── AudioSource
    └── VRC_SpatialAudioSource (3D用)
```

### Udon ビデオ制御

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Video.Components;
using VRC.SDK3.Video.Components.AVPro;

public class VideoController : UdonSharpBehaviour
{
    [SerializeField] private VRCAVProVideoPlayer avProPlayer;
    // または
    // [SerializeField] private VRCUnityVideoPlayer unityPlayer;

    [SerializeField] private VRCUrl defaultUrl;

    private bool _isPlaying = false;

    void Start()
    {
        // 初期化
    }

    public override void Interact()
    {
        // トグル再生
        if (_isPlaying)
        {
            avProPlayer.Stop();
            _isPlaying = false;
        }
        else
        {
            avProPlayer.PlayURL(defaultUrl);
            _isPlaying = true;
        }
    }

    // ビデオイベント
    public override void OnVideoStart()
    {
        Debug.Log("Video started");
        _isPlaying = true;
    }

    public override void OnVideoEnd()
    {
        Debug.Log("Video ended");
        _isPlaying = false;
    }

    public override void OnVideoError(VRC.SDK3.Components.Video.VideoError videoError)
    {
        Debug.LogError($"Video error: {videoError}");
        _isPlaying = false;
    }
}
```

### URL 同期付きビデオプレイヤー

```csharp
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.SDK3.Video.Components.AVPro;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class SyncedVideoPlayer : UdonSharpBehaviour
{
    [SerializeField] private VRCAVProVideoPlayer videoPlayer;

    [UdonSynced, FieldChangeCallback(nameof(SyncedUrl))]
    private VRCUrl _syncedUrl;

    public VRCUrl SyncedUrl
    {
        get => _syncedUrl;
        set
        {
            _syncedUrl = value;
            if (_syncedUrl != null && _syncedUrl.Get() != "")
            {
                videoPlayer.PlayURL(_syncedUrl);
            }
        }
    }

    public void PlayVideo(VRCUrl url)
    {
        if (!Networking.IsOwner(gameObject))
        {
            Networking.SetOwner(Networking.LocalPlayer, gameObject);
        }

        SyncedUrl = url;
        RequestSerialization();
    }
}
```

---

## 最適化

### オーディオ最適化

```
圧縮設定:

BGM (長い音声):
├── Load Type: Streaming
├── Compression Format: Vorbis
├── Quality: 70%
└── Sample Rate: 44100 Hz

効果音 (短い音声):
├── Load Type: Decompress On Load
├── Compression Format: Vorbis
├── Quality: 50-70%
└── Preload Audio Data: ✅

環境音 (ループ):
├── Load Type: Compressed In Memory
├── Compression Format: Vorbis
├── Quality: 50%
└── Loop: ✅
```

### ビデオ最適化

```
⚠️ 制限事項:

ワールド内ビデオプレイヤー数:
├── 推奨: 1-2 つ
└── 最大: 厳密な制限なし（パフォーマンス依存）

同時再生:
├── 同時再生は避ける
└── 必要な場合は低解像度

解像度設定:
├── PC: 1080p まで
├── Quest: 720p 推奨
└── Maximum Resolution で制限
```

### メモリに関する考慮事項

```
ビデオプレイヤーのメモリ影響:

RenderTexture サイズ:
├── 1920x1080: ~8MB
├── 1280x720: ~4MB
└── 854x480: ~2MB

対策:
□ 必要な解像度のみ使用
□ 使用しない時は停止
□ RenderTexture を適切なサイズに
```

---

## トラブルシューティング

### オーディオの問題

| 問題 | 原因 | 解決策 |
|-------|-------|----------|
| 音が聞こえない | Volume = 0 | Volume 確認 |
| 音が聞こえない | Spatial Blend 設定ミス | 2D/3D 確認 |
| 3D定位しない | Enable Spatialization = false | 有効化 |
| 音が大きすぎ/小さすぎ | Gain 設定 | 調整 |
| 遠くで聞こえない | Far 設定が小さい | Far を増加 |

### ビデオの問題

| 問題 | 原因 | 解決策 |
|-------|-------|----------|
| 再生されない | URL 非対応 | AVPro + 対応URL |
| Quest で再生されない | URL 非対応 | 直接URL使用 |
| 音が出ない | Speaker 未設定 | AVProVideoSpeaker 追加 |
| 黒画面 | RenderTexture 未接続 | Material 確認 |
| カクつく | 高解像度 | Maximum Resolution 下げる |

### よくあるオーディオコードの問題

```csharp
// ❌ 問題: AudioSource キャッシュなし
void PlaySound()
{
    GetComponent<AudioSource>().Play(); // 毎回検索
}

// ✅ 解決: キャッシュ使用
private AudioSource _audioSource;

void Start()
{
    _audioSource = GetComponent<AudioSource>();
}

void PlaySound()
{
    _audioSource.Play();
}
```

### デバッグのヒント

```csharp
// オーディオ状態確認
Debug.Log($"Audio playing: {audioSource.isPlaying}");
Debug.Log($"Volume: {audioSource.volume}");
Debug.Log($"Spatial Blend: {audioSource.spatialBlend}");

// ビデオ状態確認
Debug.Log($"Video ready: {videoPlayer.IsReady}");
Debug.Log($"Video playing: {videoPlayer.IsPlaying}");
```

---

## クイックリファレンス

### VRC_SpatialAudioSource デフォルト値

```
Gain: 0 dB (World: +10 dB)
Near: 0 m
Far: 40 m
Volumetric Radius: 0 m
Enable Spatialization: true
```

### ビデオプレイヤーイベント

```csharp
public override void OnVideoStart() { }
public override void OnVideoEnd() { }
public override void OnVideoError(VideoError error) { }
public override void OnVideoReady() { }
public override void OnVideoLoop() { }
```

### オーディオ圧縮クイックガイド

| 種類 | Load Type | フォーマット | 品質 |
|------|-----------|--------|---------|
| BGM | Streaming | Vorbis | 70% |
| SFX | Decompress | Vorbis | 50-70% |
| Ambient | Compressed | Vorbis | 50% |

