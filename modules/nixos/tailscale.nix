# Tailscale VPN - shared NixOS module
{
  config,
  lib,
  ...
}:
{
  options.services.tailscale-vpn.enable = lib.mkEnableOption "Tailscale VPN";

  config = lib.mkIf config.services.tailscale-vpn.enable {
    services.tailscale = {
      enable = true;
      openFirewall = true;
    };

    # Allow Tailscale's UDP port through the firewall
    networking.firewall.allowedUDPPorts = [ 41641 ];

    # Trust the Tailscale interface for incoming traffic
    networking.firewall.trustedInterfaces = [ "tailscale0" ];
  };
}
