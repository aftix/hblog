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

      ghostwriter = pkgs.fetchFromGitHub {
        owner = "jbub";
        repo = "ghostwriter";
        rev = "51d170861940ff13a6cc5b82223ce0076015cdbe";
        hash = "sha256-yrZicOvW2v/tmeAlUFDh4+0xDeJjr+GahxEie7IFnKA=";
      };

      katex = pkgs.fetchFromGitHub {
        owner = "KaTeX";
        repo = "KaTeX";
        rev = "f93464644419ef0057cc5b314f81e439f1242935";
        hash = "sha256-JCWc7yb6u5Nq9WRe/c46wRcBivLkBxU4wND0ZoCcqts=";
      };
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
            bzip2
            katex-gen
            hugo
          ];

          src = ./.;

          buildPhase = ''
            rm -rf content/ layouts/
            cp -vR "${katex-gen}/content" content
            cp -vR "${katex-gen}/layouts" layouts
            mkdir -p themes/ghostwriter
            mkdir -p themes/github.com/KaTeX/KaTeX
            cp -vR "${ghostwriter}/"* themes/ghostwriter
            cp -vR "${katex}/"* themes/github.com/KaTeX/KaTeX
            mkdir -p public
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
