# Official Information Sources

Official information sources and access methods for VRChat SDK (UdonSharp + World SDK).

## Primary Official Sources

### VRChat Creator Docs

| Page | URL | Content |
|------|-----|---------|
| SDK Release List | `creators.vrchat.com/releases/` | All SDK release notes |
| Latest Release | `creators.vrchat.com/releases/release-3-{version}/` | Individual release details |
| Udon | `creators.vrchat.com/worlds/udon/` | Udon official documentation |
| Networking | `creators.vrchat.com/worlds/udon/networking/` | Networking |
| Persistence | `creators.vrchat.com/worlds/udon/persistence/` | Persistence |
| Components | `creators.vrchat.com/worlds/components/` | World components |
| Layers | `creators.vrchat.com/worlds/layers/` | Layer settings |
| Allowed URL List | `creators.vrchat.com/worlds/udon/string-loading/` | Allowed URL list |

**Note**: May return 403 errors, so use WebSearch to retrieve information from snippets.

### UdonSharp Docs

| Page | URL | Content |
|------|-----|---------|
| Blog/News | `udonsharp.docs.vrchat.com/news/` | UdonSharp update information |
| Release Tags | `udonsharp.docs.vrchat.com/news/tags/release/` | Release list |
| Code Examples | `udonsharp.docs.vrchat.com/examples/` | Code examples |

### VRChat Feedback (Canny)

| Page | URL | Content |
|------|-----|---------|
| Udon Feedback | `feedback.vrchat.com/udon` | Udon feature requests |
| Completed | `feedback.vrchat.com/udon?status=complete` | Completed features |
| Persistence | `feedback.vrchat.com/persistence` | Persistence-related |

### GitHub

| Repository | URL | Content |
|-----------|-----|---------|
| UdonSharp Releases | `github.com/MerlinVR/UdonSharp/releases` | Release history |
| Creator Companion | `github.com/vrchat-community/creator-companion` | VCC related |

## Version History Tracking

### SDK Version Scheme

```
SDK 3.{major}.{minor}
Example: SDK 3.10.0

major: Major feature additions
minor: Bug fixes, small changes
```

### Key Milestones

| Version | Date | Key Changes |
|---------|------|-------------|
| 3.7.1 | 2024 | StringBuilder, Regex, System.Random |
| 3.7.4 | 2024 | Persistence API |
| 3.7.6 | 2024 | Multi-platform Build & Publish |
| 3.8.0 | 2025 | PhysBone dependency sorting, Force Kinematic On Remote |
| 3.8.1 | 2025 | NetworkCallable, events with parameters, Others/Self targets |
| 3.9.0 | 2025 | Camera Dolly API, Auto Hold simplification |
| 3.10.0 | 2025 | Dynamics for Worlds |
| 3.10.1 | 2025 | Bug fixes and stability improvements |
| 3.10.2 | 2026 | EventTiming extensions, PhysBones fixes, shader time globals |
| 3.10.3 | 2026 | `VRCPlayerApi.isVRCPlus`, VRCRaycast (avatar), Mirror render-order fix |

### Checkpoints for Next Update

1. **Check the last supported version for each skill**
   ```
   unity-vrc-udon-sharp/SKILL.md "Supported SDK version" line
   unity-vrc-world-sdk-3/SKILL.md "Supported SDK version" line
   ```

2. **Check for new versions on the official releases page**
   ```
   WebSearch: "VRChat SDK Releases"
   ```

3. **Check release notes for the version gap**
   ```
   Example: 3.10.0 → 3.11.0
   WebSearch: "VRChat SDK Release 3.11.0"
   ```

4. **Classify the differences by skill**
   ```
   UdonSharp-related → unity-vrc-udon-sharp
   World settings-related → unity-vrc-world-sdk-3
   ```

## Information Gathering Flow

```
┌─────────────────────────────────────────────────────────┐
│ 1. WebSearch: "VRChat SDK {year} releases changelog"     │
│    → Identify the latest version number                  │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│ 2. WebSearch: "VRChat SDK Release 3.{new version}"       │
│    → Get release note summary                            │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│ 3. WebSearch: Feature-specific queries (parallel)        │
│    - NetworkCallable                                     │
│    - Persistence                                         │
│    - Dynamics                                            │
│    → Get details for each feature                        │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Integrate information and create diff list            │
│    → Determine files and content to update               │
└─────────────────────────────────────────────────────────┘
```

## Supplementary Sources

### Japanese Community

| Source | Example Search Query |
|--------|---------------------|
| Qiita | `site:qiita.com VRChat SDK {version}` |
| Zenn | `site:zenn.dev VRChat UdonSharp` |
| note | `site:note.com VRChat SDK update` |

### VRChat Ask Forum

```
ask.vrchat.com
- Developer Update category
- SDK-related questions and answers
```

### Twitter/X (Social Media)

```
Search: "VRChat SDK" OR "UdonSharp" new features
Accounts: @VRChat, @MerlinVR
```

## Handling Access Restrictions

### In Case of 403 Errors

1. **Use WebSearch to leverage cached/snippet content**
2. **Check GitHub mirrors/related repositories**
3. **Reference forum/community discussions**

### When Information Cannot Be Found

1. **Re-search with different keywords**
2. **Switch between Japanese/English**
3. **Broaden the date range**
4. **Search by related feature names**

## Periodic Update Timing

### Recommended Update Frequency

| Situation | Recommended Frequency |
|-----------|----------------------|
| New major version | Update immediately |
| Minor updates (.1, .2, etc.) | Within 1-2 weeks |
| Periodic check | Once per month |

### Signals That Updates Are Needed

- Release announcements on VRChat's official Twitter
- New version notifications in Creator Companion
- "Information is outdated" feedback from users
- Reports that known constraints have been resolved
