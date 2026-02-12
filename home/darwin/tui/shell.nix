{ vars, ... }: {
  programs.nushell.extraConfig = ''
    $env.PATH = ($env.PATH | append [$"($env.HOME)/.nix-profile/Applications"])
    $env.NIX_SSL_CERT_FILE = "${vars.ssl_cert_path}";

    # Sync Nix SSL certificates to Podman machine for container registry access
    if (which podman | is-not-empty) {
      try {
        let machine_status = (podman machine list --format "{{.Running}}" | lines | first)
        if $machine_status == "true" {
          open "${vars.ssl_cert_path}" | podman machine ssh "sudo tee /etc/pki/ca-trust/source/anchors/nix-ca-cert.pem > /dev/null && sudo update-ca-trust" | ignore
        }
      }
    }
  '';
}
