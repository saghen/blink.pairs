{
  description = "Rainbow highlighting and intelligent auto-pairs for Neovim";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    nixpkgs,
    fenix,
    self,
    ...
  }: let
    inherit (nixpkgs) lib;
    inherit (lib.attrsets) genAttrs mapAttrs' nameValuePair;
    inherit (lib.fileset) fileFilter toSource unions;
    inherit (lib.meta) getExe';
    inherit (lib.strings) hasPrefix;

    systems = ["x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin"];
    forAllSystems = genAttrs systems;
    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
        overlays = [fenix.overlays.default];
      });

    version = "0.4.1";
    blink-pairs-package = {
      fenix,
      makeRustPlatform,
      vimUtils,
    }: let
      inherit (fenix.minimal) toolchain;
      rustPlatform = makeRustPlatform {
        cargo = toolchain;
        rustc = toolchain;
      };
    in
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
    in {
      build-plugin = {
        type = "app";
        program =
          (pkgs.writeShellScript "build-plugin" ''
            ${getExe' pkgs.fenix.minimal.toolchain "cargo"} build --release
          '').outPath;
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
          packages = [pkgs.fenix.rust-analyzer];
        };
      }
    );

    checks = forAllSystems (system: mapAttrs' (n: nameValuePair "package-${n}") (removeAttrs self.packages.${system} ["default"]));
  };

  nixConfig = {
    extra-substituters = ["https://nix-community.cachix.org"];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs"
    ];
  };
}
