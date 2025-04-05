{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (builtins) attrNames;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.types) enum package listOf bool;
  inherit (lib.generators) mkLuaInline;
  inherit (lib.nvim.types) diagnostics mkGrammarOption;
  inherit (lib.nvim.attrsets) mapListToAttrs;

  cfg = config.vim.languages.bash;

  defaultServer = "bash-ls";
  servers = {
    bash-ls = {
      config = {
        cmd = [(getExe pkgs.bash-language-server) "start"];
        settings = {
          bashIde = {
            globPattern =
              mkLuaInline "vim.env.GLOB_PATTERN or '*@(.sh|.inc|.bash|.command)'";
          };
        };
        filetypes = ["sh" "bash"];
        root_markers = [".git"];
      };
    };
  };

  defaultFormat = "shfmt";
  formats = {
    shfmt = {
      package = pkgs.shfmt;
    };
  };

  defaultDiagnosticsProvider = ["shellcheck"];
  diagnosticsProviders = {
    shellcheck = {
      package = pkgs.shellcheck;
    };
  };
in {
  options.vim.languages.bash = {
    enable = mkEnableOption "Bash language support";

    treesitter = {
      enable = mkEnableOption "Bash treesitter" // {default = config.vim.languages.enableTreesitter;};
      package = mkGrammarOption pkgs "bash";
    };

    lsp = {
      enable = mkEnableOption "Enable Bash LSP support" // {default = config.vim.languages.enableLSP;};

      server = mkOption {
        description = "Bash LSP server to use";
        type = listOf (enum (attrNames servers));
        default = [defaultServer];
      };
    };

    format = {
      enable = mkOption {
        description = "Enable Bash formatting";
        type = bool;
        default = config.vim.languages.enableFormat;
      };
      type = mkOption {
        description = "Bash formatter to use";
        type = enum (attrNames formats);
        default = defaultFormat;
      };

      package = mkOption {
        description = "Bash formatter package";
        type = package;
        default = formats.${cfg.format.type}.package;
      };
    };

    extraDiagnostics = {
      enable = mkEnableOption "extra Bash diagnostics" // {default = config.vim.languages.enableExtraDiagnostics;};
      types = diagnostics {
        langDesc = "Bash";
        inherit diagnosticsProviders;
        inherit defaultDiagnosticsProvider;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.treesitter.enable {
      vim.treesitter.enable = true;
      vim.treesitter.grammars = [cfg.treesitter.package];
    })

    (mkIf cfg.lsp.enable {
      vim.lsp.servers =
        mapListToAttrs (name: {
          inherit name;
          value = servers.${name}.config;
        })
        cfg.lsp.server;
    })

    (mkIf cfg.format.enable {
      vim.formatter.conform-nvim = {
        enable = true;
        setupOpts.formatters_by_ft.sh = [cfg.format.type];
        setupOpts.formatters.${cfg.format.type} = {
          command = getExe cfg.format.package;
        };
      };
    })

    (mkIf cfg.extraDiagnostics.enable {
      vim.diagnostics.nvim-lint = {
        enable = true;
        linters_by_ft.sh = cfg.extraDiagnostics.types;
        linters = mkMerge (map (name: {
            ${name}.cmd = getExe diagnosticsProviders.${name}.package;
          })
          cfg.extraDiagnostics.types);
      };
    })
  ]);
}
