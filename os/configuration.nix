# Edit this file to enable what should be installed on the system
{
  pkgs,
  vars,
  ...
}: {
  users.users.${vars.os_user} = {
	isNormalUser = true;
	createHome = true;
	home = "/home/${vars.os_user}";
	extraGroups = [ "wheel" "docker"];
	shell = pkgs.nushell;
  };
  
  imports = [
	./virtualisation.nix
  ];

  environment.systemPackages = with pkgs ; [
	home-manager
  ];

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs ; [
	stdenv.cc.cc # GCC C++ runtime
	zlib # Needed by many python wheels
  ];

  wsl.enable = true;
  wsl.defaultUser = vars.os_user;
  networking.hostName = vars.system_name;

  system.stateVersion = "24.11";
} 
