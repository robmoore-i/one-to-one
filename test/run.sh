# shellcheck disable=SC2046
eval $(opam config env)
opam install ounit2
opam install httpaf
opam install lwt
opam install httpaf-lwt-unix
dune build one_to_one_test.exe
dune exec ./one_to_one_test.exe