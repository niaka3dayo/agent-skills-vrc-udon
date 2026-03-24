# VRChat World Upload Guide

Complete upload procedure and best practices.

## Table of Contents

- [Pre-Upload Checklist](#pre-upload-checklist)
- [Build & Test](#build--test)
- [Validation](#validation)
- [Upload Process](#upload-process)
- [World Settings](#world-settings)
- [Content Warnings](#content-warnings)
- [Capacity Settings](#capacity-settings)
- [Post-Upload](#post-upload)
- [Troubleshooting](#troubleshooting)

---

## Pre-Upload Checklist

### Required Checks

```
□ Scene Setup
  □ Exactly 1 VRC_SceneDescriptor exists
  □ Transforms set in Spawns
  □ Respawn Height is appropriate (well below the floor)
  □ Reference Camera configured (if needed)

□ Layers & Collision
  □ "Setup Layers for VRChat" executed
  □ Collision Matrix verified
  □ Objects placed on appropriate layers

□ Components
  □ VRC_Pickup has Collider + Rigidbody
  □ VRC_Station has Collider
  □ VRC_ObjectSync has Rigidbody
  □ Mirror is default OFF

□ Performance
  □ 45+ FPS in VR
  □ Lightmaps baked
  □ Minimal realtime lights

□ Content
  □ No copyright-infringing content
  □ No terms-of-service violating content
  □ Content Warnings set
```

### Recommended Checks

```
□ Local verification with Build & Test
□ Multi-player testing conducted
□ Quest support (if applicable)
□ World thumbnail prepared
□ World description written
```

---

## Build & Test

### Local Testing Procedure

```
1. VRChat SDK > Show Control Panel
2. Builder tab
3. "Build & Test New Build" section
4. Number of Clients: Number of test clients desired
5. Force Non-VR: Force Desktop mode (optional)
6. "Build & Test" button
```

### Test Items

```
Single Player Test:
□ Spawn position is correct
□ Respawn Height causes correct respawn
□ Wall/floor collision is correct
□ Pickup can be grabbed/released
□ Station can be entered/exited
□ Mirror works (when enabled)
□ Audio plays correctly
□ Video player works

Multi-Player Test (multiple clients):
□ Spawn positions are distributed
□ Pickup sync is correct
□ Station sync is correct
□ UdonSynced variables sync
□ State syncs for Late Joiners
□ Ownership transfer works correctly
```

### Number of Clients Settings

```
Recommended by test purpose:

Basic functionality: 1 client
Sync testing: 2 clients
Multi-player testing: 3-4 clients

Notes:
- Each client is an independent VRChat instance
- Consumes PC resources
- First build takes extra time
```

---

## Validation

### Validation Check Procedure

```
1. VRChat SDK > Show Control Panel
2. Builder tab
3. Check Validations section
4. Resolve errors (red)
5. Review warnings (yellow)
```

### Common Validation Errors

| Error | Cause | Solution |
|-------|-------|----------|
| Missing SceneDescriptor | No VRCWorld | Add VRCWorld Prefab |
| Layer setup required | Layers not configured | Click "Setup Layers" |
| Build size too large | Build is too big | Reduce assets |
| Script errors | Compilation errors | Fix scripts |
| Missing references | Reference errors | Fix references |

### Auto-Fix Feature

```
Some issues can be auto-fixed:

Items with "Auto Fix" button:
- Layer collision matrix
- Project settings
- Quality settings

Items that can't be auto-fixed:
- Script errors
- Missing references
- Component misconfiguration
```

---

## Upload Process

### Upload Procedure

```
1. Confirm no Validation errors

2. VRChat SDK > Show Control Panel

3. Builder tab

4. Click "Build and Upload" button

5. For first upload:
   - Enter World Name
   - Enter Description
   - Set Content Warnings
   - Set Capacity

6. For updates:
   - Review changes
   - Modify settings as needed

7. Click "Upload"

8. Wait for upload to complete
```

### Blueprint ID

```
Blueprint ID:
- Unique identifier for the world
- Stored in VRC_PipelineManager
- Overwrites/updates with the same ID

New creation:
- Click "Attach a New Blueprint ID"
- Or upload from a new scene

Updating an existing world:
- Maintain the same Blueprint ID
- Only settings can be changed
```

### World Thumbnail

```
Thumbnail settings:

Method 1: Screenshot
- Click "Take Screenshot" on the upload screen
- Captures the current Scene View

Method 2: External image
- Import a PNG/JPG
- Select as thumbnail

Recommended specifications:
- Resolution: 1200x900 or higher
- Aspect ratio: 4:3
- File size: < 10MB
```

---

## World Settings

### Basic Settings

| Setting | Description | Recommendation |
|---------|-------------|----------------|
| Name | World name | Easy to search |
| Description | Description text | List features and notes |
| Tags | Tags | Select appropriate tags |
| Release Status | Publication status | Private → Public |

### Release Status

```
Private:
- Only you and invited people can access
- For testing and development

Friends:
- Only friends can access
- For limited release

Friends+:
- Friends of friends can also access

Public:
- Everyone can access
- Appears in search results
```

---

## Content Warnings

### Required Settings

```
Must be set if applicable:

□ Adult Language
  - Contains adult language

□ Blood/Gore
  - Blood or grotesque content

□ Fear/Horror
  - Horror or fear elements

□ Nudity/Suggestive
  - Nudity or sexually suggestive content

□ Substance Use
  - Drug or alcohol depiction

□ Violence
  - Violent content
```

### Importance of Warning Settings

```
⚠️ Warning:

If not set:
- World may be deleted for terms violation
- Account restrictions possible

If incorrectly set:
- Affects user experience
- Inappropriate flags may drive users away

Best practices:
- Select all that apply
- When in doubt, select it
```

---

## Capacity Settings

### Types of Capacity

| Setting | Purpose | Behavior |
|---------|---------|----------|
| **Recommended Capacity** | Recommended count | UI display, search filter |
| **Maximum Capacity** | Maximum count | Hard limit |

### Configuration Guidelines

```
Recommended Capacity:
- Number of players for comfortable play
- Number where performance is maintained
- Displayed in UI

Maximum Capacity:
- Technically supportable maximum
- No more can join beyond this
- Usually 2-4x the Recommended

Examples:
- Small world: 8-16 players
- Medium world: 20-32 players
- Large world: 40-80 players
```

### Capacity Best Practices

```
✅ Recommended:

1. Determine through performance testing
   - Actually test with multiple people
   - Check FPS

2. Consider network load
   - Many synced objects → lower count
   - Static world → higher count

3. Consider the world's purpose
   - Event use → higher count
   - Small group use → lower count

❌ Avoid:

- Setting to maximum without justification
- Deciding without testing
- Ignoring performance
```

---

## Post-Upload

### Verification Items

```
1. Verify on VRChat website
   - https://vrchat.com/home/
   - "My Worlds" section

2. Verify in-game
   - World search
   - Confirm correct display

3. Check settings
   - Publication status
   - Thumbnail
   - Description
```

### Notes After Updating

```
After update:
- Existing instances remain on the old version
- Only new instances use the new version
- Cache clearing may be needed

Propagation time:
- Usually reflects within minutes
- Search indexing may take hours
```

### World Management

```
On the VRChat website:

□ Change Release Status
□ Update description
□ Change tags
□ Change Capacity
□ Change Content Warnings
□ Change thumbnail
□ Delete world
```

---

## Troubleshooting

### Upload Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Build failed" | Build error | Check Console for errors |
| "Upload failed" | Network error | Retry |
| "File too large" | Size exceeded | Reduce assets |
| "Not logged in" | Not logged in | Log in via SDK Panel |
| "Validation failed" | Validation error | Fix errors |

### Common Problems

#### World not found

```
Cause:
1. Still set to Private
2. Search index not yet updated
3. World name is too generic

Solution:
1. Change to Public
2. Wait a few hours
3. Change to a unique name
4. Access via direct URL
```

#### Upload takes too long

```
Cause:
1. Build size is large
2. Slow network
3. Server congestion

Solution:
1. Optimize assets
2. Use a stable connection
3. Retry after some time
```

#### Changes not reflected

```
Cause:
1. Joined an old instance
2. Cache issue
3. Blueprint ID issue

Solution:
1. Create a new instance
2. Clear VRChat cache
3. Verify Blueprint ID
```

### Debug Checklist

```
□ No errors in Console
□ All Validations pass
□ Blueprint ID is correct
□ Logged in
□ Stable network connection
□ Sufficient disk space
```

---

## Platform-Specific Upload

### PC + Quest Cross-Platform

```
Procedure:

1. Build for PC
   - Platform: Windows
   - Build & Upload

2. Build for Quest
   - Switch Platform to Android
   - Apply Quest optimizations
   - Build & Upload (same Blueprint ID)

3. Verify on both platforms

Notes:
- Use the same Blueprint ID
- Features may differ between platforms
- Some features are disabled on Quest
```

### Quest-Only World

```
Settings:

1. Platform: Android
2. Apply Quest optimizations
3. Build & Upload

Notes:
- PC users cannot access
- Quest optimization is required
```

---

## Quick Reference

### Upload Checklist (Minimum)

```
□ VRC_SceneDescriptor × 1
□ Spawns configured
□ Validation passed
□ Build & Test verified
□ Content Warnings set
□ Upload
```

### SDK Panel Shortcuts

```
VRChat SDK > Show Control Panel

Builder tab:
- Build & Test
- Build & Upload
- Validations

Content Manager tab:
- Manage uploaded content

Settings tab:
- SDK settings
```

### Key URLs

| Purpose | URL |
|---------|-----|
| VRChat Home | https://vrchat.com/home/ |
| My Worlds | https://vrchat.com/home/worlds |
| World Detail | https://vrchat.com/home/world/{worldId} |

## See Also

- [performance.md](performance.md) - Pre-upload performance checklist and Quest optimization requirements
- [troubleshooting.md](troubleshooting.md) - Upload errors and common build failures
