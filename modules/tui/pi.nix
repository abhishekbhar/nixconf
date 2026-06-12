{
  pkgs,
  ...
}:

let
  pi = pkgs.buildNpmPackage {
    pname = "pi-coding-agent";
    version = "0.79.1";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-0.79.1.tgz";
      sha256 = "1pcpylvn3xj0pzkbik4i71jq0cv54kcl8qf8n5g8ilm81wnbysx9";
    };
    sourceRoot = "package";
    npmDepsHash = "sha256-CUTMzOmKoSzq/yq+8DEIb7rJVw+2Vt12lWN5nFX5Eo0=";
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
