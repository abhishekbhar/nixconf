{ pkgs, ... }: {
  # https://github.com/catppuccin/helix
  programs.helix = {
    enable = true;
    package = pkgs.helix;
    # defaultEditor = true;
    settings = {
      theme = "dracula_at_night";
      editor = {
        line-number = "relative";
        cursorline = true;
        color-modes = true;
        lsp.display-messages = true;
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        indent-guides.render = true;
        file-picker = {
          hidden = false;
          ignore = true;
        };
        soft-wrap = { enable = true; };
        bufferline = "multiple";
      };
      keys.normal = {
        space = {
          space = "file_picker";
          w = ":w";
          q = ":q";
        };
        esc = [ "collapse_selection" "keep_primary_selection" ];
      };
    };
  };

  # xdg.configFile = {
  #   "helix/ignore" = ''
  #     .direnv/*
  #     .git/*
  #   '';
  # };
}
