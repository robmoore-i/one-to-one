#!/bin/bash
set -eu

sudo chown -R opam:opam /one-to-one
sudo apt-get install m4 -y
opam update
opam install dune

set +eu