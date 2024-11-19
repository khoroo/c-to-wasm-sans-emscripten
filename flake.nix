{
  description = "Build environment without libc using clang";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, utils }: 
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            hardening.all = false;
          };
        };
        clang_nolibc = pkgs.wrapCCWith {
          cc = pkgs.clang;
          bintools = pkgs.wrapBintoolsWith {
            bintools = pkgs.binutils-unwrapped;
            libc = null;
          };
        };
        nolibc_stdenv = pkgs.overrideCC pkgs.stdenv clang_nolibc;
        llvmPackages = pkgs.llvmPackages_17;

      in {
        devShell = nolibc_stdenv.mkDerivation {
          name = "nolibc-env";
          nativeBuildInputs = [
            clang_nolibc 
            pkgs.wabt
            pkgs.python3
            llvmPackages.llvm
            llvmPackages.lld
          ];
          hardeningDisable = [ "all" ];

          shellHook = ''
            function compile_wasm() {
              local name="$1"
              ${clang_nolibc}/bin/clang --target=wasm32 -emit-llvm -c -S "$name.c" -o "$name.ll"
              ${llvmPackages.llvm}/bin/llc -march=wasm32 -filetype=obj "$name.ll" -o "$name.o"
              ${llvmPackages.lld}/bin/wasm-ld --no-entry --export-all -o "$name.wasm" "$name.o"
              rm "$name.ll"
            }
          '';
        };
      }
    );
}
