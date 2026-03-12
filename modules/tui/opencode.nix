{
  config,
  lib,
  pkgs,
  mostlatestpkgs,
  vars,
  ...
}:
{
  # Ensure you have enabled opencode module
  programs.opencode.enable = true;

  # Use opencode from mostlatestpkgs (nixpkgs master) for latest version
  programs.opencode.package = mostlatestpkgs.opencode;

  # Optionally, Configure settings (like theme or model)
  programs.opencode.settings = {
    theme = "opencode";
    plugin = [
      "opencode-claude-auth@latest"
      "opencode-github-auth@latest"
    ];
    provider = {
      anthropic = {
        models = {
          "claude-sonnet-4-5" = {
            name = "Claude Sonnet 4.5";
            limit = {
              context = 200000;
              output = 64000;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
          };
          "claude-opus-4-5" = {
            name = "Claude Opus 4.5";
            limit = {
              context = 200000;
              output = 64000;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
            variants = {
              low = {
                thinkingConfig = {
                  thinkingBudget = 8192;
                };
              };
              max = {
                thinkingConfig = {
                  thinkingBudget = 32768;
                };
              };
              github = {
                models = {
                  "gpt-4.1" = {
                    name = "GPT 4.1";
                    limit = {
                      context = 1000000;
                      output = 32000;
                    };
                    modalities = {
                      input = [
                        "text"
                        "image"
                        "pdf"
                      ];
                      output = [ "text" ];
                    };
                  };
                  "gpt-4.1-mini" = {
                    name = "GPT 4.1 Mini";
                    limit = {
                      context = 1000000;
                      output = 32000;
                    };
                    modalities = {
                      input = [
                        "text"
                        "image"
                        "pdf"
                      ];
                      output = [ "text" ];
                    };
                  };
                  "gpt-4.1-nano" = {
                    name = "GPT 4.1 Nano";
                    limit = {
                      context = 1000000;
                      output = 32000;
                    };
                    modalities = {
                      input = [
                        "text"
                        "image"
                        "pdf"
                      ];
                      output = [ "text" ];
                    };
                  };
                  "o4-mini" = {
                    name = "O4 Mini";
                    limit = {
                      context = 1000000;
                      output = 32000;
                    };
                    modalities = {
                      input = [
                        "text"
                        "image"
                        "pdf"
                      ];
                      output = [ "text" ];
                    };
                    variants = {
                      low = {
                        thinkingConfig = {
                          thinkingBudget = 8192;
                        };
                      };
                      high = {
                        thinkingConfig = {
                          thinkingBudget = 32768;
                        };
                      };
                    };
                  };
                  "o3" = {
                    name = "O3";
                    limit = {
                      context = 1000000;
                      output = 100000;
                    };
                    modalities = {
                      input = [
                        "text"
                        "image"
                        "pdf"
                      ];
                      output = [ "text" ];
                    };
                    variants = {
                      low = {
                        thinkingConfig = {
                          thinkingBudget = 8192;
                        };
                      };
                      medium = {
                        thinkingConfig = {
                          thinkingBudget = 16384;
                        };
                      };
                      high = {
                        thinkingConfig = {
                          thinkingBudget = 32768;
                        };
                      };
                    };
                  };
                  "o3-mini" = {
                    name = "O3 Mini";
                    limit = {
                      context = 1000000;
                      output = 100000;
                    };
                    modalities = {
                      input = [
                        "text"
                        "image"
                        "pdf"
                      ];
                      output = [ "text" ];
                    };
                    variants = {
                      low = {
                        thinkingConfig = {
                          thinkingBudget = 8192;
                        };
                      };
                      medium = {
                        thinkingConfig = {
                          thinkingBudget = 16384;
                        };
                      };
                      high = {
                        thinkingConfig = {
                          thinkingBudget = 32768;
                        };
                      };
                    };
                  };
                };
              };
            };
          };
          "claude-3-5-sonnet" = {
            name = "Claude 3.5 Sonnet";
            limit = {
              context = 200000;
              output = 8192;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
          };
          "claude-3-opus" = {
            name = "Claude 3 Opus";
            limit = {
              context = 200000;
              output = 4096;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
          };
          "claude-3-sonnet" = {
            name = "Claude 3 Sonnet";
            limit = {
              context = 200000;
              output = 4096;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
          };
          "claude-3-haiku" = {
            name = "Claude 3 Haiku";
            limit = {
              context = 200000;
              output = 4096;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
          };
        };
      };
      google = {
        models = {
          "antigravity-gemini-3-pro" = {
            name = "Gemini 3 Pro (Antigravity)";
            limit = {
              context = 1048576;
              output = 65535;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
            variants = {
              low = {
                thinkingLevel = "low";
              };
              high = {
                thinkingLevel = "high";
              };
            };
          };
          "antigravity-gemini-3.1-pro" = {
            name = "Gemini 3.1 Pro (Antigravity)";
            limit = {
              context = 1048576;
              output = 65535;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
            variants = {
              low = {
                thinkingLevel = "low";
              };
              high = {
                thinkingLevel = "high";
              };
            };
          };
          "antigravity-gemini-3-flash" = {
            name = "Gemini 3 Flash (Antigravity)";
            limit = {
              context = 1048576;
              output = 65536;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
            variants = {
              minimal = {
                thinkingLevel = "minimal";
              };
              low = {
                thinkingLevel = "low";
              };
              medium = {
                thinkingLevel = "medium";
              };
              high = {
                thinkingLevel = "high";
              };
            };
          };
          "gemini-2.5-flash" = {
            name = "Gemini 2.5 Flash (Gemini CLI)";
            limit = {
              context = 1048576;
              output = 65536;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
          };
          "gemini-2.5-pro" = {
            name = "Gemini 2.5 Pro (Gemini CLI)";
            limit = {
              context = 1048576;
              output = 65536;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
          };
          "gemini-3-flash-preview" = {
            name = "Gemini 3 Flash Preview (Gemini CLI)";
            limit = {
              context = 1048576;
              output = 65536;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
          };
          "gemini-3-pro-preview" = {
            name = "Gemini 3 Pro Preview (Gemini CLI)";
            limit = {
              context = 1048576;
              output = 65535;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
          };
          "gemini-3.1-pro-preview" = {
            name = "Gemini 3.1 Pro Preview (Gemini CLI)";
            limit = {
              context = 1048576;
              output = 65535;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
          };
          "gemini-3.1-pro-preview-customtools" = {
            name = "Gemini 3.1 Pro Preview Custom Tools (Gemini CLI)";
            limit = {
              context = 1048576;
              output = 65535;
            };
            modalities = {
              input = [
                "text"
                "image"
                "pdf"
              ];
              output = [ "text" ];
            };
          };
        };
      };
    };
    mcp = {
      context7 = {
        type = "remote";
        url = "https://mcp.context7.com/mcp";
      }
      // lib.optionalAttrs (vars.context7ApiKey != null) {
        headers = {
          "CONTEXT7_API_KEY" = vars.context7ApiKey;
        };
      };
    };
  };
}
