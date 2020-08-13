# shellcheck disable=SC2046
eval $(opam config env)
opam install base
opam install lwt
opam install httpaf
opam install httpaf-lwt-unix
dune build one_to_one.exe
dune exec ./one_to_one.exe
