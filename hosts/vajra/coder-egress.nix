# Coder workspace egress firewall (Phase 5 hardening).
#
# NOT imported by default. Flip it on by adding `./coder-egress.nix` to the
# imports in system.nix AFTER you've sorted out how dev workspaces will reach
# Maven Central / Gradle Plugin Portal / npm registry. Three options:
#
#   (a) Internal Maven mirror + npm proxy (Sonatype Nexus, Verdaccio). Cleanest.
#   (b) Squid with SSL bump + domain allow-list. Strong; needs corp CA in image.
#   (c) Add the relevant public CIDRs to the allow-list below (sloppy, but
#       blocks the real exfil targets like GitHub/pastebin/S3 directly).
#
# Until one of those is in place, enabling this file will break `mvn install`,
# `gradle build`, and `npm install` inside workspaces.
#
# Also note: the Coder agent inside each workspace phones home to
# CODER_ACCESS_URL (https://coder.abhibhr.in -> Cloudflare). When this is on,
# either override CODER_AGENT_URL on the agent to talk to vajra over the LAN,
# or add Cloudflare's published CIDR list to the allow-list below.
{ ... }:
{
  networking.firewall.extraCommands = ''
    # ---------------- CODER-EGRESS chain ----------------
    iptables -N CODER-EGRESS 2>/dev/null || iptables -F CODER-EGRESS

    # Return traffic
    iptables -A CODER-EGRESS -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN

    # DNS — workspaces are pinned to PiHole on server2 (192.168.11.102:53)
    # via `dns = [...]` in the template. PiHole returns server2's LAN IP
    # for git.abhibhr.in / coder.abhibhr.in (split-horizon).
    iptables -A CODER-EGRESS -d 192.168.11.102 -p udp --dport 53 -j RETURN
    iptables -A CODER-EGRESS -d 192.168.11.102 -p tcp --dport 53 -j RETURN

    # server2:443 covers both:
    #   - git.abhibhr.in (Forgejo clone/push)
    #   - coder.abhibhr.in (Coder agent phone-home; resolves to LAN via PiHole)
    # The wildcard *.coder.abhibhr.in is only used by the dev's BROWSER, not
    # by workspace-internal code, so we don't need to allow that path here.
    iptables -A CODER-EGRESS -d 192.168.11.102 -p tcp --dport 443 -j RETURN

    # TODO(maven): allow internal Maven mirror or Sonatype Nexus
    # iptables -A CODER-EGRESS -d <mirror-ip> -p tcp --dport <port> -j RETURN

    # TODO(nix): the workspace image is Nix-based. Run-time `nix develop` pulls
    # from the binary cache, so enabling this firewall WILL break flake shells
    # unless cache.nixos.org (Fastly) is reachable. Either run an internal Nix
    # cache/substituter and allow it here, or allow Fastly's published CIDRs.
    # iptables -A CODER-EGRESS -d <nix-cache-ip> -p tcp --dport 443 -j RETURN

    # Default deny — log + reject so devs see a clear "permission denied"
    iptables -A CODER-EGRESS -j LOG --log-prefix "coder-egress drop: " --log-level 6
    iptables -A CODER-EGRESS -j REJECT --reject-with icmp-net-prohibited

    # ---------------- hook into DOCKER-USER ----------------
    iptables -C DOCKER-USER -i br-coderws -j CODER-EGRESS 2>/dev/null \
      || iptables -I DOCKER-USER -i br-coderws -j CODER-EGRESS
  '';

  networking.firewall.extraStopCommands = ''
    iptables -D DOCKER-USER -i br-coderws -j CODER-EGRESS 2>/dev/null || true
    iptables -F CODER-EGRESS 2>/dev/null || true
    iptables -X CODER-EGRESS 2>/dev/null || true
  '';
}
