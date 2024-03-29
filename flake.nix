{
  description = "aftix.xyz blog site, built with hugo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages = rec {
        katex-gen = pkgs.mkYarnPackage {
          pname = "katex-gen";
          version = "1.0.0";
          src = ./.;

          configurePhase = ''
            ln -s "$node_modules" node_modules
          '';

          buildPhase = ''
            export HOME="$(mktemp -d)"
            yarn --offline exec tsc
            yarn --offline run render
          '';

          distPhase = "true";

          installPhase = ''
            mkdir "$out"
            mv content/ "$out/."
            mv layouts/ "$out/."
          '';

          meta = with pkgs.lib; {
            homepage = "https://github.com/aftix/hblog";
            license = licenses.mit;
          };
        };

        hblog = pkgs.stdenv.mkDerivation {
          pname = "hblog";
          version = "1.0.0";

          buildInputs = with pkgs; [
            katex-gen
            hugo
          ];

          src = ./.;

          buildPhase = ''
            mkdir -p public
            rm -rf content/ layouts/
            cp -R ${katex-gen}/content .
            cp -R ${katex-gen}/layouts .
            hugo -d public
          '';

          installPhase = ''
            mkdir -p "$out"
            tar cvf site.tar public/
            bzip2 -z site.tar
            mv site.tar.bz2 "$out/."
          '';

          meta = with pkgs.lib; {
            homepage = "https://aftix.xyz";
            license = licenses.mit;
          };
        };
        default = hblog;
      };

      devShells.default = pkgs.mkShell {
        name = "hblog-shell";

        HOSTNAME = "aftix.xyz";
        buildInputs = with pkgs; [
          hugo
          nodejs
          yarn
          just
        ];
      };
    });
}
