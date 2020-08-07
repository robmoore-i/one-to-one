module Oto = One_to_one_lib;;

let () =
  print_endline "Hello, world!";
  Oto.run_server_for_n_seconds 8080 2.0
