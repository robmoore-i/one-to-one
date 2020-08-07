# shellcheck disable=SC2046
eval $(opam config env)
opam install httpaf
opam install lwt
dune build one_to_one.exe
dune exec ./one_to_one.exe
