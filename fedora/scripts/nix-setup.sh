#!/bin/bash
# curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
#nix run home-manager/master -- init --switch
