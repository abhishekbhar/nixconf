{
  pkgs,
  ...
}:

let
  pi = pkgs.buildNpmPackage {
    pname = "pi-coding-agent";
    version = "0.79.8";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-0.79.8.tgz";
      sha256 = "494de83a62df3f7a3c3197ba00870890f3bcc3561bbcc9b9d0a9c62dfb4e3e62";
    };
    sourceRoot = "package";
    npmDepsHash = "sha256-nIVVyGkkMWHs0oSHjHCHcuXtV1fXREIgDgYNhjTFrgY=";
    postPatch = ''
      cp ${./pi-lock.json} npm-shrinkwrap.json
    '';
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out/lib/node_modules/pi-coding-agent $out/bin
      cp -r . $out/lib/node_modules/pi-coding-agent/
      chmod +x $out/lib/node_modules/pi-coding-agent/dist/cli.js
      ln -s $out/lib/node_modules/pi-coding-agent/dist/cli.js $out/bin/pi
    '';
  };
in {
  home.packages = [ pi pkgs.nodejs ];
}
