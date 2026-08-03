# null0x686F Mod Suite

![Project Zomboid](https://img.shields.io/badge/Project%20Zomboid-B42-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Performance](https://img.shields.io/badge/Performance-O(1)-brightgreen)

Landing page and shared release tooling for the **null0x686F** Project Zomboid (Build 42) mod suite — a deliberate counter-movement against low-quality "vibe coded" Workshop mods. Every mod here is written O(1)-clean: no unbounded `OnTick`/`OnPlayerUpdate` scans, no per-frame allocations, algorithmic complexity stated explicitly in every PR.

This repo does not ship a mod itself. It hosts:
- **This README**, the single index of every mod in the suite.
- **`.github/workflows/mod-release.yml`**, a reusable GitHub Actions workflow (`workflow_call`) that each mod repo's own release pipeline calls to zip the mod, create the GitHub Release, and publish to Steam Workshop — so that logic lives in one place instead of being copy-pasted (and drifting) across every mod repo.

## Mods

| Mod | Description | Repo | Workshop |
|---|---|---|---|
| **CoreLib** | Shared, zero-overhead library — Global Debug Panel, leveled logger, version-compat helpers. Hard dependency for every other mod below. | [PZmodB42_null0x686F-CoreLib](https://github.com/lucashort7/PZmodB42_null0x686F-CoreLib) | [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3772694554) |
| **CombatText** | Floating damage numbers and combat HUD. | [PZmodB42_null0x686F-CombatText](https://github.com/lucashort7/PZmodB42_null0x686F-CombatText) | _pending first Workshop publish_ |
| **ContextCleaner** | O(1) right-click context menu cleaner with a custom hide/fold rule builder UI. | [PZmodB42_null0x686F-ContextCleaner](https://github.com/lucashort7/PZmodB42_null0x686F-ContextCleaner) | _pending first Workshop publish_ |
| **QoL** | Quality-of-life feature pack, built from scratch for zero FPS impact. | [PZmodB42_null0x686F-QoL](https://github.com/lucashort7/PZmodB42_null0x686F-QoL) | _pending first Workshop publish_ |
| **DangerSensorHUD** | Screen-edge flash HUD warning of zombies chasing you outside your field of view. Still an early prototype, not yet split into its own repo. | _(not yet a standalone repo)_ | _pending first Workshop publish_ |

## Shared release workflow

`mod-release.yml` is called by each mod repo like:

```yaml
jobs:
  publish:
    uses: lucashort7/PZmodB42_null0x686F-Suite/.github/workflows/mod-release.yml@main
    with:
      mod_id: null0x686F_CoreLib
      tag_name: v0.1.4
      published_file_id: '3772694554'
      publish_steam: true
      prerelease: false
    secrets: inherit
```

It zips `Contents/`, attaches it to a GitHub Release, verifies the target Steam Workshop item actually exists (via the unauthenticated `ISteamRemoteStorage/GetPublishedFileDetails` endpoint — a plain HTTP status check on the Workshop page is not reliable, it always returns 200 even for nonexistent items), then publishes via `lucashort7/steam-workshop-deploy@v3` — our own fork, because the upstream action supports neither `previewFile` nor `visibility`/`title`/`description`. Don't "fix" this back to upstream.

**Status (verified 2026-08-03):** all four mod repos call this workflow, from both `release.yml` and `dev-release.yml`, pinned at `@main`.
