{
  description = "Rainbow highlighting and intelligent auto-pairs for Neovim";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs = {
    nixpkgs,
    self,
    ...
  }: let
    inherit (nixpkgs) lib;
    inherit (lib.attrsets) genAttrs getLib mapAttrs' nameValuePair;
    inherit (lib.fileset) fileFilter toSource unions;
    inherit (lib.strings) hasPrefix;

    systems = ["x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = genAttrs systems;
    nixpkgsFor = forAllSystems (system: nixpkgs.legacyPackages.${system});

    version = "0.4.1";
    blink-pairs-package = {
      rustPlatform,
      vimUtils,
    }:
      vimUtils.buildVimPlugin {
        pname = "blink.pairs";
        inherit version;
        src = toSource {
          root = ./.;
          fileset = fileFilter (file: file.hasExt "lua") ./lua;
        };

        preInstall = ''
          mkdir -p target/release
          ln -s $rust_lib/lib/libblink_pairs.* target/release/
        '';

        env.rust_lib = rustPlatform.buildRustPackage {
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

    apps = forAllSystems (system: let
      pkgs = nixpkgsFor.${system};
      build-plugin = pkgs.writeShellScript "build-plugin" ''
        mkdir -p ./target/release
        ln -s ${getLib self.packages.${system}.blink-pairs.rust_lib}/lib/*.so ./target/release/
      '';
    in {
      build-plugin = {
        type = "app";
        program = build-plugin.outPath;
        meta.description = "Build the rust library and link it to ./target/release/";
      };
    });

    devShells = forAllSystems (
      system: let
        pkgs = nixpkgsFor.${system};
        packages = self.packages.${system};
      in {
        default = pkgs.mkShell {
          name = "blink";
          inputsFrom = [
            packages.blink-pairs
            packages.blink-pairs.rust_lib
          ];
          packages = [pkgs.rust-analyzer];
        };
      }
    );

    checks = forAllSystems (system: mapAttrs' (n: nameValuePair "package-${n}") (removeAttrs self.packages.${system} ["default"]));
  };
}
