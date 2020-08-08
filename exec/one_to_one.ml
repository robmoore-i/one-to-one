open Lwt.Infix
module Oto = One_to_one_lib;;

let () =
  print_endline "Pick a mode ('client' or 'server')";
  print_string "> "; flush stdout;
  Lwt_main.run (Oto.pick_session_mode_from_stdin
  >>= (fun mode ->
    match mode with
      | Oto.Mode.Client -> Oto.start_in_client_mode ()
      | Oto.Mode.Server -> Oto.start_in_server_mode ()
    ));;
