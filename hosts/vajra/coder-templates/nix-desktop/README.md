# nix-desktop — Coder template: GUI workspace with Nix + browsers

## Overview

A minimal [Coder](https://coder.com) workspace template that gives developers a **full desktop environment** in the browser, with **code protection** — all code stays server-side.

```
┌───────────────────────────────────────────────────────────┐
│  Dev's Browser                                            │
│  ┌─────────────────────┐  ┌─────────────────────────────┐ │
│  │  code-server        │  │  Desktop (noVNC)            │ │
│  │  (VS Code in web)   │  │  ┌──────┐ ┌──────────────┐ │ │
│  │  • Full IDE         │  │  │Chrome│ │ Zed / code-  │ │ │
│  │  • Terminal         │  │  │      │ │ server (web) │ │ │
│  │  • Git GUI          │  │  └──────┘ └──────────────┘ │ │
│  └─────────────────────┘  └─────────────────────────────┘ │
│  All traffic goes through Coder proxy — no direct access   │
└───────────────────────────────────────────────────────────┘
```

## What's inside

| Component | Access | Notes |
|-----------|--------|-------|
| **code-server** (VS Code) | Browser via Coder app `code-server` | Primary editor, terminal + git built-in |
| **XFCE4 Desktop** | Browser via Coder app `desktop` | Full Linux desktop in your browser |
| **Google Chrome** | Inside the desktop | `google-chrome` from the XFCE menu |
| **Zed editor** | Inside the desktop | `zed` from the XFCE menu or terminal |
| **Nix (flakes)** | CLI + direnv | Single-user Nix, flakes enabled, direnv auto-loads project `.envrc` |
| **Git** | CLI + code-server | Identity locked to Coder user (no push impersonation) |

## Quick start

```bash
# 1. On your Coder server (vajra), push this template:
coder templates push nix-desktop \
  --directory /home/abhishekbhar/nixconf/hosts/vajra/coder-templates/nix-desktop

# 2. Developers create a workspace via the Coder UI:
#    Workspaces → Create Workspace → nix-desktop
#    Set CPU / Memory / Desktop resolution as needed.

# 3. Once running, two apps appear in the workspace dashboard:
#    - "VS Code"   → code-server in browser
#    - "Desktop"   → XFCE4 desktop with Chrome + Zed
#    - "Frontend"  → preview your app on port 3000
```

## Workspace parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cpu` | 4 | vCPU limit (2–8) |
| `memory_gb` | 8 | RAM in GiB (4–16) |
| `desktop_enabled` | true | Start GUI? Disable to save ~800 MB RAM |
| `desktop_resolution` | 1920×1080 | FHD / QHD / 4K virtual display |

## How the GUI works

1. **TigerVNC** runs on display `:1` (port 5901, loopback only)
2. **noVNC** (`websockify`) serves the VNC client as a web page on port 6080
3. **Coder app proxy** (`*.coder.abhibhr.in`) makes it accessible from any browser
4. Developers open the `desktop` app → see XFCE4 → launch Chrome/Zed from the menu

No VNC client needed — everything works in the browser.

## Code protection measures

| Layer | What it does |
|-------|-------------|
| **No direct connections** | Workspace agent only talks to Coder server. No laptop↔workspace tunnels. |
| **No port forwarding** | Devs can't SSH tunnel out. |
| **Container hardening** | `privileged=false`, all capabilities dropped, `no-new-privileges` |
| **Git identity lock** | `GIT_AUTHOR_NAME` / `GIT_COMMITTER_NAME` forced to Coder user. |
| **Dedicated bridge** | `br-coderws` network — egress firewall (iptables) can target workspace traffic specifically. |
| **Browser-only** | noVNC + code-server are both web apps. No SSH / SCP needed. |

For full egress lockdown, enable `coder-egress.nix` on vajra (see `hosts/vajra/coder-egress.nix`).

## Image build process

```bash
# The image is built automatically when a workspace starts (or on push).
# To rebuild manually:
docker build -t coder-nix-desktop:latest \
  /home/abhishekbhar/nixconf/hosts/vajra/coder-templates/nix-desktop/build
```

The image is ~1.5 GB and caches locally. Only rebuilds when the Dockerfile changes.

## Differences from the `nix` template

| Aspect | `nix` | `nix-desktop` |
|--------|-------|---------------|
| Desktop | ❌ No | ✅ XFCE4 + noVNC |
| Chrome  | ❌ No | ✅ Google Chrome |
| Zed     | ❌ No | ✅ Zed editor |
| RAM usage | ~300 MB | ~1.1 GB (desktop + Chrome) |
| code-server | ✅ Yes | ✅ Yes |
| Nix + flakes | ✅ Yes | ✅ Yes |
| Image size | ~700 MB | ~1.5 GB |
