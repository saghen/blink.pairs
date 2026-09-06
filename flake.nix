{
  description = "Rainbow highlighting and intelligent auto-pairs for Neovim";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    blink-lib.url = "github:saghen/blink.lib";
    blink-lib.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    nixpkgs,
    blink-lib,
    self,
    ...
  }: let
    inherit (nixpkgs) lib;
    inherit (lib.attrsets) genAttrs mapAttrs' nameValuePair;
    inherit (lib.fileset) fileFilter toSource unions;
    inherit (lib.strings) hasPrefix;

    systems = ["x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = genAttrs systems;
    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
        overlays = [blink-lib.overlays.default];
      });

    version = "0.7.0";
    blink-pairs-package = {
      rustPlatform,
      vimPlugins,
      vimUtils,
    }:
      vimUtils.buildVimPlugin {
        pname = "blink.pairs";
        inherit version;
        src = toSource {
          root = ./.;
          fileset = unions [
            (fileFilter (file: file.hasExt "lua") ./lua)
            ./queries
          ];
        };

        dependencies = [
          (vimPlugins.blink-lib or (throw "vimPlugins.blink-lib not found; did you include its overlay?"))
        ];

        preInstall = ''
          mkdir -p lib
          ln -s $parser_lib/lib/libblink_pairs_parser.* lib/
        '';

        # nvimRequireCheckHook adds the plugin to be tested to the rtp multiple
        # times. This means blink.lib finds multiple instances of the
        # library, causing the require checks to fail.
        nvimSkipModules = [
          "blink.pairs.rust"
          "blink.pairs.mappings.wrap.motion"
          "blink.pairs.mappings.wrap.treesitter"
        ];

        env.parser_lib = rustPlatform.buildRustPackage {
          pname = "blink-pairs-lib";
          inherit version;
          src = toSource {
            root = ./.;
            fileset = unions [
              (fileFilter (file: file.hasExt "rs") ./.)
              (fileFilter (file: hasPrefix "Cargo" file.name) ./.) # Cargo.*
              ./.cargo
            ];
          };
          cargoLock.lockFile = ./Cargo.lock;
          doCheck = false;
        };

        passthru = {inherit rustPlatform;};
      };
  in {
    packages = forAllSystems (system: rec {
      blink-pairs = nixpkgsFor.${system}.callPackage blink-pairs-package {};
      default = blink-pairs;
    });

    overlays.default = final: prev: {
      vimPlugins = prev.vimPlugins.extend (_: _: {
        blink-pairs = final.callPackage blink-pairs-package {};
      });
    };

    devShells = forAllSystems (
      system: let
        pkgs = nixpkgsFor.${system};
        packages = self.packages.${system};
      in {
        default = pkgs.mkShell {
          name = "blink";
          inputsFrom = [
            packages.blink-pairs
            packages.blink-pairs.parser_lib
          ];
          packages = [pkgs.rust-analyzer];
        };
      }
    );

    checks = forAllSystems (system: mapAttrs' (n: nameValuePair "package-${n}") (removeAttrs self.packages.${system} ["default"]));
  };
}
