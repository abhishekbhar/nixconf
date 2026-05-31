# Minimal Nix-flake Coder template — design

Date: 2026-05-31
Host: vajra
Status: approved, pending implementation plan

## Goal

Replace the existing `java` Coder template (heavy Ubuntu 24.04 image with JDK 21 /
Maven / Gradle / Node baked in) with a **minimal Debian-slim image that ships only
Nix (with flakes enabled) plus the workspace host tooling**. Language toolchains move
out of the image and into each project's `flake.nix`. Cloning a repo that has a
`flake.nix` + `.envrc` makes the dev environment load **automatically** via direnv —
in the integrated terminal and through the VS Code direnv extension.

## Current state (what exists today)

- `hosts/vajra/coder-templates/java/main.tf` — Coder + Docker Terraform template.
  - Container runs non-root `user = "1000:1000"`, `cap-drop ALL`,
    `no-new-privileges:true`.
  - Persistent `docker_volume` mounted at `/home/coder`.
  - Dedicated bridge `br-coderws`, DNS pinned to PiHole `192.168.11.102`.
  - code-server started by the agent `startup_script` at `/usr/bin/code-server`
    on `0.0.0.0:13337`, surfaced via `coder_app "code-server"`.
  - CPU / memory parameters; image tag `coder-java:latest`.
- `hosts/vajra/coder-templates/java/build/Dockerfile` — `FROM ubuntu:24.04` with
  Temurin JDK 21, Maven, Gradle, Node 20, code-server, non-root `coder` UID 1000.
- `hosts/vajra/coder-egress.nix` — egress firewall, **not enabled** (not imported in
  `system.nix`). So workspaces can currently reach the public internet, including
  `cache.nixos.org`.

## Decisions (locked)

1. **Replace in place.** Rename `coder-templates/java/` → `coder-templates/nix/`.
   Drop all baked-in JDK/Maven/Gradle/Node — flakes provide them per project.
2. **Auto-setup = direnv + nix-direnv + VS Code direnv extension** (`mkhl.direnv`).
3. **Base = `debian:stable-slim`** + official Nix installer with flakes pre-enabled
   (not the `nixos/nix` image).
4. **Single-user Nix** install owned by `coder` (UID 1000), no daemon — works under
   the existing `cap-drop ALL` + `no-new-privileges` + non-root hardening.
5. **`/nix` is ephemeral from the image layer** (no dedicated volume). Baked packages
   present on every start; rebuilds only re-pull when the image changes.
6. **Hardening unchanged** — keep non-root UID 1000, `cap-drop ALL`,
   `no-new-privileges`.

## Architecture

### Terraform (`main.tf`)
Near-identical to today. Changes only:
- Image resource name/tag `coder-java:latest` → `coder-nix:latest`.
- Build context path follows the renamed `nix/build` dir.
- Comment updates (no longer "Java dev workspace").
Unchanged: CPU/mem parameters, agent + `startup_script` (still calls
`/usr/bin/code-server`), `coder_app` blocks, docker network, DNS pin, persistent
home volume, container user/hardening.

### Image (`build/Dockerfile`)
`FROM debian:stable-slim`, then:
1. apt (no-install-recommends): `ca-certificates curl git xz-utils sudo bash`.
2. Create non-root `coder` user, UID 1000, home `/home/coder`.
3. Single-user Nix install **as coder**:
   `sh <(curl -L https://nixos.org/nix/install) --no-daemon`.
   `/nix` owned by coder; no `nix-daemon`.
4. `/etc/nix/nix.conf`: `experimental-features = nix-command flakes`.
5. As coder: `nix profile install nixpkgs#direnv nixpkgs#nix-direnv`.
6. `~/.bashrc`: source the Nix profile, `eval "$(direnv hook bash)"`; create
   `~/.config/direnv/direnvrc` that sources nix-direnv (fast cached `use flake`).
7. code-server via official install script → `/usr/bin/code-server` (keeps
   `main.tf` startup_script unchanged); then
   `code-server --install-extension mkhl.direnv` and a minimal `settings.json` so the
   integrated terminal + extension pick up the flake env.
8. `USER coder`, `WORKDIR /home/coder`.

## Persistence behavior

- `/home/coder` → persistent Docker volume (as today). On the **first** workspace
  creation Docker seeds the fresh named volume from the image's `/home/coder`, so
  `.bashrc`, direnv config, and code-server extensions land in the volume.
  Subsequent rebuilds preserve user data but do not re-seed image updates to
  `/home/coder` (accepted tradeoff).
- `/nix` → ephemeral, comes from the image layer each start. Per-project
  `nix develop` artifacts cache in `/nix` for the life of the container.

## Usage (the payoff)

```
git clone https://git.abhibhr.in/me/myproj && cd myproj
# project has flake.nix + .envrc containing: use flake
direnv allow          # one-time per project
# → toolchain (JDK/Node/etc. declared by the flake) auto-loads now and on every cd
```

## Out of scope (YAGNI)

- No JDK/Maven/Gradle/Node in the image.
- No multi-user nix-daemon.
- No dedicated `/nix` volume.
- No hardening changes.
- No egress-firewall changes (it stays off). But add a TODO comment in
  `coder-egress.nix`: when enabling it, allow `cache.nixos.org` so run-time
  `nix develop` works.

## Caveats

- The Nix installer needs internet at **build** time (fine now).
- `nix develop` needs `cache.nixos.org` at **run** time — relevant only once
  `coder-egress.nix` is enabled.

## Verification

- `docker build` of `nix/build` succeeds.
- Container as UID 1000 runs: `nix flake --version`, `direnv version`,
  `code-server --version`.
- Throwaway repo with `flake.nix` + `.envrc` (`use flake`): `direnv allow` loads the
  shell; declared tool resolves on `which`.
