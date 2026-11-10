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
| SDK Packages | `github.com/vrchat/packages/releases` | Stable and beta SDK releases; `releases/latest` is the newest stable one |
| UdonSharp | `github.com/vrchat-community/UdonSharp` | UdonSharp source and documentation (ships inside the Worlds SDK) |
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

The version-by-version feature table is kept in one place:
`skills/unity-vrc-udon-sharp/references/sdk-migration.md` ("Version summary"). The World SDK view of
the same history is the "SDK Version Features" table in `skills/unity-vrc-world-sdk-3/CHEATSHEET.md`.

### Checkpoints for Next Update

1. **Check the active and verified target for each skill**
   ```
   unity-vrc-udon-sharp/SKILL.md "Active support / last verified" line
   unity-vrc-world-sdk-3/SKILL.md "Active support / last verified" line
   ```

2. **Check for new versions**
   ```
   gh api repos/vrchat/packages/releases/latest --jq '.tag_name'
   ```
   The weekly SDK Watch workflow runs the same call and opens a `type: sdk-update` Issue.

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
│ 1. gh api repos/vrchat/packages/releases/latest          │
│    → The latest stable version (betas are skipped)       │
└──────────────────────────┬──────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Release notes for each version up to that one         │
│    creators.vrchat.com/releases/ (WebSearch if blocked)  │
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
