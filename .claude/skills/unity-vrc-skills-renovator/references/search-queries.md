# Effective Search Query Collection

Search query collection for gathering the latest VRChat SDK (UdonSharp + World SDK) information.

## Basic Searches (Run Every Time)

### Release Information

```
VRChat SDK {year} new features updates changelog
```
Example: `VRChat SDK 2025 new features updates changelog`

```
UdonSharp VRChat SDK 3.{version} changes
```
Example: `UdonSharp VRChat SDK 3.11 changes`

```
VRChat Worlds SDK {year} UdonSharp
```
Example: `VRChat Worlds SDK 2025 UdonSharp`

### Version-Specific

```
VRChat SDK Release 3.{major}.{minor}
```
Example: `VRChat SDK Release 3.10.0`

## World SDK Component Searches

### Component Changes

```
VRChat World SDK components new features {year}
VRChat SDK VRC_SceneDescriptor new settings
VRChat SDK VRC_Pickup VRC_Station changes
```

### World Optimization

```
VRChat world optimization guidelines {year}
VRChat SDK performance limits draw calls
```

### Lighting & Audio

```
VRChat world lighting baked lightmap {year}
VRChat SDK audio video player changes
```

### Layers & Collision

```
VRChat world layer collision matrix changes
VRChat SDK new layers {year}
```

## UdonSharp Feature-Specific Searches

### Networking

```
VRChat SDK NetworkCallable parameters UdonSharp
VRChat SDK SendCustomNetworkEvent parameters
VRChat Udon network events with parameters
```

### Persistence

```
VRChat SDK persistence PlayerData world data
VRChat PlayerObject PlayerData difference
VRChat OnPlayerRestored event
```

### Dynamics (PhysBones/Contacts)

```
VRChat SDK PhysBones Contacts Udon API worlds
VRChat SDK 3.10 dynamics worlds
VRChat OnContactEnter OnPhysBoneGrab
```

### New System Namespaces

```
VRChat SDK System.Random StringBuilder RegularExpressions Udon
VRChat Udon new namespaces exposed
```

### GetComponent / Generics

```
VRChat SDK GetComponent UdonSharpBehaviour inheritance generic
UdonSharp GetComponent fix generic
```

## Japanese Searches (Supplementary)

```
VRChat SDK latest changes
UdonSharp new features {year}
VRChat world development SDK update
```

## Search Tips

### Effective Keywords

| Purpose | Example Keywords |
|---------|-----------------|
| Release notes | "release", "changelog", "what's new" |
| New features | "new feature", "added", "now supports" |
| Changes | "changed", "updated", "improved" |
| Fixes | "fixed", "resolved", "bugfix" |
| Deprecations | "deprecated", "removed", "breaking change" |

### Search Order

1. **First, search official release notes**
   ```
   VRChat SDK Releases {version}
   ```

2. **Next, UdonSharp-specific changes**
   ```
   UdonSharp {version} release
   ```

3. **Then, feature-specific detailed searches**
   ```
   VRChat SDK {feature name} {year}
   ```

### Parallel Search Recommendations

The following searches have no dependencies and can be run in parallel:

```
// Parallel group 1 (release information)
- VRChat SDK {year} new features updates changelog
- UdonSharp VRChat SDK 3.{version} changes

// Parallel group 2 (feature-specific)
- VRChat SDK NetworkCallable parameters
- VRChat SDK persistence PlayerData
- VRChat SDK PhysBones Contacts worlds
```

## Evaluating Search Results

### High-Reliability Sources

| Source | Reliability | Notes |
|--------|------------|-------|
| creators.vrchat.com | Highest | Official documentation |
| udonsharp.docs.vrchat.com | Highest | UdonSharp official |
| feedback.vrchat.com | High | Official feedback |
| github.com/vrchat-community | High | Official GitHub |
| qiita.com (VRChat tag) | Medium | Japanese community |
| zenn.dev | Medium | Japanese tech articles |

### Checking Information Freshness

- Check the article date
- Check the SDK version mentioned
- Wait for official release for "beta"/"preview" information

## When WebFetch Is Not Available

The VRChat official site (creators.vrchat.com) may return 403 errors, so:

1. **Get an overview via WebSearch**
2. **Extract information from search result snippets**
3. **Combine multiple search results to supplement information**

Alternative sources:
- GitHub Issues/Discussions
- VRChat Ask Forum (ask.vrchat.com)
- Discord (not searchable, but useful as a reference)
