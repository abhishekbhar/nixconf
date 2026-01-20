{
  pkgs,
  lib,
  vars,
  ...
}: {
  programs.nushell = {
    enable = true;
    settings = {
      use_ansi_coloring = true;
      show_banner = false;

      table = {
        mode = "rounded";
        index_mode = "always";
        show_empty = true;
        trim = {
          methodology = "wrapping";
          wrapping_try_keep_words = true;
          truncating_suffix = "...";
        };
      };

      completions = {
        case_sensitive = false;
        quick = true;
        partial = true;
        algorithm = "prefix";
      };

      filesize = {
        unit = "MB";
      };

      cursor_shape = {
        emacs = "blink_underscore";
        vi_insert = "blink_line";
        vi_normal = "block";
      };

      footer_mode = 25;
      float_precision = 2;
      bracketed_paste = true;
      edit_mode = "emacs";
      render_right_prompt_on_last_line = false;
      buffer_editor = "hx";
    };
    environmentVariables = {
      ENV_CONVERSIONS.PATH = {
        from_string = lib.hm.nushell.mkNushellInline "{|s| $s | split row (char esep) }";
        to_string = lib.hm.nushell.mkNushellInline "{|v| $v | str join (char esep) }";
      };
#      NIX_SSL_CERT_FILE = vars.ssl_cert_path;
      EDITOR = "hx";
    };
    shellAliases = {
      n = "nvim";
      v = "nvim";
      vi = "nvim";
      vim = "nvim";
      emacs = "nvim";

      # Colors
      ip = "ip -color";
      grep = "grep --color=auto";
      diff = "diff --color=auto";
      tree = "tree -C";

      # Misc
      t = "tldr";
      df = "duf --hide special";
      cat = "bat";
      cp = "cp -v";
      mv = "mv -v";
      rm = "rm -v";
      rmdir = "rmdir -p";
      lg = "lazygit";
      ld = "lazydocker";
      lj = "jjui";
      y = "yazi";
      zj = "zellij";
      c = "clear";
      la = "ls -a";
      ll = "ls -l";
      ij = "idea-community";
      ipy = "pycharm-community";
      gm = "gomatrix";
      d = "docker";
      dc = "docker-compose";
    };
    extraConfig = ''
      $env.PATH = ($env.PATH | append [$"($env.HOME)/.nix-profile/bin" $"($env.HOME)/.local/bin" "/nix/var/nix/profiles/default/bin"])
      def random-art [] {
        # Define two external command/argument lists
        let choices = [
          [ "${pkgs.dwt1-shell-color-scripts}/bin/colorscript", "random" ],
          [ "${pkgs.krabby}/bin/krabby", "random", "--no-mega", "--no-gmax", "--no-regional", "--no-title", "-s" ]
        ]

        # Pick one at random and run it
        run-external (echo $choices | shuffle | first)
      }
      alias ff = ${pkgs.fastfetch}/bin/fastfetch --logo-type data-raw --logo (random-art | decode utf8) -c ~/.config/fastfetch/config.jsonc
      ff
    '';
  };

  home.file."./.config/fastfetch/config.jsonc".text = ''
      {
      "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
      "logo": {
      "height": 9,
      "width": 18,
      "padding": {
        "top": 1
        }
      },
      "display": {
          "separator": " -> "
      },
      "modules": [
          "break",
          {
              "type": "title",
              "keyWidth": 10,
    	"format": "         {6}{7}{8}"
          },
          {
              "type": "custom",
              "format": " ─────────────────────────── "
          },
          {
              "type": "kernel",
              "key": " ",
              "keyColor": "yellow"
          },
          {
              "type": "wm",
              "key": " ",
              "keyColor": "blue"
          },
          {
              "type": "shell",
              "key": " ",
              "keyColor": "yellow"
          },
          {
              "type": "terminal",
              "key": " ",
              "keyColor": "blue"
          },
          /*
          {
              "type": "packages",
              "key": "󰏖 ",
              "keyColor": "yellow"
          },
          */
          {
              "type": "memory",
              "key": "󰍛 ",
              "keyColor": "magenta",
              // format: used / total
              "format": "{1} / {2}"
          },
          {
              "type": "uptime",
              "key": "󰔛 ",
              "keyColor": "green"
          },
          {
              "type": "custom",
              "format": " ─────────────────────────── "
          },
          {
              "type": "custom",
              "format": "   \u001b[31m  \u001b[32m  \u001b[33m  \u001b[34m  \u001b[35m  \u001b[36m  \u001b[37m  \u001b[90m "
          },
    "break",
      ]
    }
  '';
}
