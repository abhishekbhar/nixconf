# Minimal Nix-flake Coder Template Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace vajra's `java` Coder template with a minimal Debian-slim image that ships only Nix (flakes enabled) + direnv/nix-direnv + code-server, so cloning a project with a `flake.nix` + `.envrc` auto-loads its dev environment.

**Architecture:** A single Dockerfile (`FROM debian:stable-slim`) installs single-user Nix as the non-root `coder` user (UID 1000), enables flakes via `/etc/nix/nix.conf`, installs `direnv` + `nix-direnv` from nixpkgs, wires the bash shell + a direnvrc, and installs code-server + the `mkhl.direnv` VS Code extension. The Terraform (`main.tf`) is unchanged except the image tag. All language toolchains come from per-project flakes, not the image.

**Tech Stack:** Docker, Debian, Nix (single-user, flakes), direnv + nix-direnv, code-server, Coder + Terraform (kreuzwerker/docker provider).

---

## Context for the implementer (read first)

- This template lives at `hosts/vajra/coder-templates/java/` and will be **renamed** to `.../nix/`. Two files: `main.tf` (Terraform) and `build/Dockerfile`.
- The container runs **non-root** (`user = "1000:1000"`), with `cap-drop ALL` and `no-new-privileges:true`. The Dockerfile MUST end as a usable non-root `coder` UID-1000 user. **Do not** introduce a multi-user nix-daemon — it won't work under this hardening. Use **single-user** Nix.
- `/home/coder` is a **persistent Docker volume**. On first workspace creation Docker seeds the fresh volume from the image's `/home/coder`, so anything we bake under `/home/coder` (`.bashrc`, direnv config, code-server extensions/settings) lands in the volume. `/nix` is **not** a volume — it comes from the image layer on every start.
- **Docker is NOT available on this Mac.** The `docker build`/`docker run` verification in Task 4 must be run on a Docker host (vajra, or any machine with Docker). File-editing tasks (1–3) are committed regardless; Task 4 is a manual verification gate.
- The design spec is at `docs/superpowers/specs/2026-05-31-coder-nix-flake-template-design.md`.

---

## Task 1: Rename template dir and retag the image

**Files:**
- Rename: `hosts/vajra/coder-templates/java/` → `hosts/vajra/coder-templates/nix/`
- Modify: `hosts/vajra/coder-templates/nix/main.tf` (image tag + one comment)

- [ ] **Step 1: Rename the directory with git**

```bash
cd /Users/abhishekbhar/projects/nixconf
git mv hosts/vajra/coder-templates/java hosts/vajra/coder-templates/nix
```

- [ ] **Step 2: Verify the rename landed**

Run: `git status --short && ls hosts/vajra/coder-templates/nix`
Expected: `main.tf` and `build/Dockerfile` listed under `nix/`; git shows the renames staged (`R  ...java/main.tf -> ...nix/main.tf`).

- [ ] **Step 3: Retag the docker image in `main.tf`**

In `hosts/vajra/coder-templates/nix/main.tf`, find the `docker_image "main"` resource and change the image name.

Old:
```hcl
resource "docker_image" "main" {
  name = "coder-java:latest"
```

New:
```hcl
resource "docker_image" "main" {
  name = "coder-nix:latest"
```

- [ ] **Step 4: Verify no stale `coder-java` / `java` references remain in main.tf**

Run: `grep -n -i "coder-java\|java" hosts/vajra/coder-templates/nix/main.tf`
Expected: no output (empty). If anything prints, update those comments/strings to the Nix equivalent.

- [ ] **Step 5: Commit**

```bash
git add hosts/vajra/coder-templates/
git commit -m "Change: rename Coder java template to nix, retag image coder-nix"
```

---

## Task 2: Rewrite the Dockerfile as minimal Debian + single-user Nix

**Files:**
- Modify (full replace): `hosts/vajra/coder-templates/nix/build/Dockerfile`

- [ ] **Step 1: Replace the entire Dockerfile with the minimal Nix image**

Overwrite `hosts/vajra/coder-templates/nix/build/Dockerfile` with exactly this:

```dockerfile
# Minimal dev workspace image for Coder on vajra.
# - Debian slim base, no language toolchains baked in.
# - Single-user Nix (no daemon) with flakes enabled.
# - direnv + nix-direnv so a project's flake.nix + .envrc auto-loads on `cd`.
# - code-server (browser IDE) + the mkhl.direnv VS Code extension.
# - Non-root user `coder` UID 1000 (matches main.tf `user = "1000:1000"`).
#
# Toolchains (JDK, Node, etc.) come from each project's flake — not this image.
FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    USER=coder \
    HOME=/home/coder

# Minimal host tooling. xz-utils + curl are required by the Nix installer.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git xz-utils sudo bash \
    && rm -rf /var/lib/apt/lists/*

# Non-root user matching the container UID/GID enforced by main.tf.
RUN useradd --create-home --uid 1000 --shell /bin/bash coder

# Enable flakes globally before any nix command runs (read by single-user nix too).
RUN mkdir -p /etc/nix \
 && printf 'experimental-features = nix-command flakes\n' > /etc/nix/nix.conf

# Pre-create the Nix store owned by coder so the single-user installer needs no sudo.
RUN mkdir -m 0755 /nix && chown coder:coder /nix

# Code-server installs as root to /usr/bin/code-server (main.tf startup_script
# calls that exact path).
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Everything below runs as the non-root coder user.
USER coder
WORKDIR /home/coder

# Single-user Nix install (no daemon). /nix is already coder-owned.
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon --no-channel-add

# Install direnv + nix-direnv into coder's nix profile.
RUN . /home/coder/.nix-profile/etc/profile.d/nix.sh \
 && nix profile install nixpkgs#direnv nixpkgs#nix-direnv

# Wire the interactive shell: source Nix, hook direnv, source nix-direnv's direnvrc.
RUN mkdir -p /home/coder/.config/direnv \
 && printf 'source %s/.nix-profile/share/nix-direnv/direnvrc\n' "$HOME" \
      > /home/coder/.config/direnv/direnvrc \
 && printf '\n# --- Nix + direnv (added by image) ---\nif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi\nexport PATH="$HOME/.nix-profile/bin:$PATH"\neval "$(direnv hook bash)"\n' \
      >> /home/coder/.bashrc

# Install the direnv VS Code extension + minimal settings so the integrated
# terminal/extension pick up the flake environment automatically.
RUN . /home/coder/.nix-profile/etc/profile.d/nix.sh \
 && /usr/bin/code-server --install-extension mkhl.direnv \
 && mkdir -p /home/coder/.local/share/code-server/User \
 && printf '{\n  "direnv.restart.automatic": true\n}\n' \
      > /home/coder/.local/share/code-server/User/settings.json

# Make sure the workspace mount point exists (matches main.tf startup_script).
RUN mkdir -p /home/coder/workspace
```

- [ ] **Step 2: Sanity-check the Dockerfile for the hard requirements**

Run: `grep -n -e "^FROM" -e "^USER" -e "no-daemon" -e "nix-command flakes" -e "mkhl.direnv" hosts/vajra/coder-templates/nix/build/Dockerfile`
Expected: `FROM debian:stable-slim`, `USER coder` present, single-user `--no-daemon` install, flakes line, and the direnv extension line all appear. The `USER coder` line must come **before** the nix install line.

- [ ] **Step 3: Commit**

```bash
git add hosts/vajra/coder-templates/nix/build/Dockerfile
git commit -m "New: minimal Debian + single-user Nix (flakes) Coder image with direnv"
```

---

## Task 3: Note the Nix cache in the egress firewall comments

**Files:**
- Modify: `hosts/vajra/coder-egress.nix` (comment + a commented-out example rule)

**Why:** The egress firewall is currently off. When it's eventually enabled, run-time `nix develop` needs `cache.nixos.org` reachable, or every flake shell will fail. This adds a visible reminder next to the existing Maven TODO — no behavior change (the line stays commented).

- [ ] **Step 1: Add a commented Nix-cache allow reminder after the Maven TODO**

In `hosts/vajra/coder-egress.nix`, find:

```
    # TODO(maven): allow internal Maven mirror or Sonatype Nexus
    # iptables -A CODER-EGRESS -d <mirror-ip> -p tcp --dport <port> -j RETURN
```

Replace it with:

```
    # TODO(maven): allow internal Maven mirror or Sonatype Nexus
    # iptables -A CODER-EGRESS -d <mirror-ip> -p tcp --dport <port> -j RETURN

    # TODO(nix): the workspace image is Nix-based. Run-time `nix develop` pulls
    # from the binary cache, so enabling this firewall WILL break flake shells
    # unless cache.nixos.org (Fastly) is reachable. Either run an internal Nix
    # cache/substituter and allow it here, or allow Fastly's published CIDRs.
    # iptables -A CODER-EGRESS -d <nix-cache-ip> -p tcp --dport 443 -j RETURN
```

- [ ] **Step 2: Verify the edit**

Run: `grep -n "TODO(nix)" hosts/vajra/coder-egress.nix`
Expected: one match.

- [ ] **Step 3: Commit**

```bash
git add hosts/vajra/coder-egress.nix
git commit -m "Docs: note Nix binary cache must be allowed when enabling coder-egress"
```

---

## Task 4: Build + smoke-test the image (manual, on a Docker host)

**Files:** none (verification only)

**Run this on vajra or any machine with Docker** — Docker is not on the dev Mac. If you cannot reach a Docker host now, mark this task blocked and report; do NOT claim the image works without running it.

- [ ] **Step 1: Build the image**

Run (from the repo root on the Docker host):
```bash
docker build -t coder-nix:latest hosts/vajra/coder-templates/nix/build
```
Expected: build completes successfully, ending `naming to docker.io/library/coder-nix:latest`. The Nix install and `nix profile install` steps require internet.

- [ ] **Step 2: Verify the core tools run as UID 1000 in an interactive login shell**

Run:
```bash
docker run --rm --user 1000:1000 coder-nix:latest \
  bash -lc 'nix --version && nix flake --help >/dev/null && echo flakes-ok && direnv version && /usr/bin/code-server --version'
```
Expected: a Nix version prints, `flakes-ok` prints (proves `nix-command`/`flakes` are enabled — no "experimental feature" error), a direnv version prints, and a code-server version prints.

- [ ] **Step 3: Verify direnv auto-loads a flake dev shell**

Run:
```bash
docker run --rm --user 1000:1000 coder-nix:latest bash -lc '
  set -e
  mkdir -p /home/coder/t && cd /home/coder/t
  cat > flake.nix <<"EOF"
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in { devShells.x86_64-linux.default = pkgs.mkShell { packages = [ pkgs.jq ]; }; };
}
EOF
  echo "use flake" > .envrc
  direnv allow
  direnv exec . jq --version
'
```
Expected: ends by printing a `jq-1.x` version, proving the flake dev shell loaded a tool that is NOT in the base image.

- [ ] **Step 4: Record the result**

If all three steps pass, the image is verified — note it in the workspace/PR. If any step fails, capture the exact error and stop (do not push a broken template); debug with superpowers:systematic-debugging.

---

## Task 5: Push the workspace image and update the Coder template

**Files:** none (operational — run where `coder` CLI + Docker live, i.e. vajra)

**Why:** Editing `main.tf` doesn't change running workspaces. The template must be pushed to the Coder server, and existing workspaces rebuilt, to pick up `coder-nix:latest`. Skip/defer if you only intended to land the code change.

- [ ] **Step 1: Push the updated template**

Run (from vajra, in the template dir):
```bash
cd hosts/vajra/coder-templates/nix
coder templates push   # accept the prompt; uses main.tf in the current dir
```
Expected: Coder uploads the template and reports a new version. (The Docker provider builds `coder-nix:latest` from `./build` on first workspace start.)

- [ ] **Step 2: Recreate/restart a workspace and confirm**

Rebuild a workspace from the new template version, open the VS Code (code-server) app, open a terminal, and run `nix flake --version` and `direnv version`. Expected: both succeed; cloning a repo with `flake.nix` + `.envrc` then `direnv allow` loads its toolchain.

- [ ] **Step 3: Note completion**

Report that the template is pushed and a workspace was verified end-to-end.

---

## Self-review notes

- **Spec coverage:** rename + retag (Task 1), Debian+single-user-Nix+flakes+direnv+nix-direnv+code-server+mkhl.direnv (Task 2), egress TODO for `cache.nixos.org` (Task 3), build/run/flake verification (Task 4), template push (Task 5). All spec sections covered.
- **Hardening:** Dockerfile ends as non-root `coder` UID 1000, single-user Nix, no daemon — consistent with `main.tf` `user = "1000:1000"` + `cap-drop ALL` + `no-new-privileges`. `main.tf` hardening untouched.
- **Persistence:** all baked user state lives under `/home/coder` (seeded into the volume on first create); `/nix` intentionally ephemeral-from-image — matches the design's option A.
- **No placeholders:** every code/edit step shows exact content; `<mirror-ip>`/`<nix-cache-ip>` are intentionally inside commented-out (disabled) iptables examples, mirroring the file's existing style.
