arch := `uname -m`
platform := `uname -s`

default:
    @just --list

build arch=arch platform=platform:
    @nix build ".?submodules=1#packages.{{arch}}-$(echo {{platform}} | tr A-Z a-z).default"

check:
    @nix flake check '.?submodules=1'
