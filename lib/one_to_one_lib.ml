let average a b =
  (a +. b) /. 2.0;;

let square_plus_one a =
  let a_squared = a * a in
  a_squared + 1;;

let cube_plus_one a =
  let accumulator = ref 1 in
  (accumulator := !accumulator + (a * a * a));
  !accumulator;;

let first_times_last l =
  match l with
    | (h :: r) ->
      let rec last l =
        match l with
          | (_ :: (h3 :: r2)) -> last (h3 :: r2)
          | (h2 :: []) -> h2
          | [] -> 0
      in
      h * (last r)
    | [] -> 0;;

let read_first_line filename =
  let input_channel = open_in filename in
  try
    let line = input_line input_channel in
    close_in input_channel;
    line
  with e ->
    close_in_noerr input_channel;
    raise e;;

let read_first_line_lwt filename =
  (* The file will close by default. See: https://ocsigen.org/lwt/5.2.0/api/Lwt_io *)
  let file_descriptor_promise = Lwt_unix.openfile filename [O_RDONLY; O_NONBLOCK; O_CLOEXEC] 0 in
  (* Read the first line of a file from it's file descriptor *)
  let read_first_line_from_file_descriptor file_descriptor =
    let channel = Lwt_io.of_fd ~mode:Lwt_io.input file_descriptor in
    let line_promise = Lwt_io.read_line channel in
    line_promise in
  (* Deliver the promised file descriptor to the function which reads the first
     line of the corresponding file *)
  Lwt.bind file_descriptor_promise read_first_line_from_file_descriptor;;

let last_seven_in_response_body = Http_client.last_seven_in_response_body;;

let http_get = Http_client.http_get;;

let powers_of_two_and_three x =
  let x_squared = x * x in
  (x_squared, x_squared * x);;

let run_server_for_n_seconds = Http_server.run_server_for_n_seconds;;

let run_server_during_lwt_task = Http_server.run_server_during_lwt_task;;

module Mode = struct
  type mode =
  | Client
  | Server;;

  exception Unrecognised of string;;

  let to_string mode = match mode with
    | Client -> "client_mode"
    | Server -> "server_mode";;
end;;

let pick_session_mode mode_promise =
  Lwt.bind mode_promise (fun mode ->
    match mode with
      | "client" -> Lwt.return Mode.Client
      | "server" -> Lwt.return Mode.Server
      | unrecognised_mode -> Lwt.fail (Mode.Unrecognised (String.concat " " ["Unrecognised mode:"; unrecognised_mode])));;

let pick_session_mode_from_stdin =
  let mode_promise = Lwt_io.read_line Lwt_io.stdin in
  pick_session_mode mode_promise;;

let start_in_client_mode _ = Lwt.return (print_endline "Running in client mode");;

let start_in_server_mode _ = Lwt.return (print_endline "Running in server mode");;