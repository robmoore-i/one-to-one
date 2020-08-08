module Oto = One_to_one_lib;;

let () =
  print_endline "Pick a mode ('client' or 'server')";
  print_endline (Oto.Mode.to_string (Lwt_main.run Oto.pick_session_mode_from_stdin));;
