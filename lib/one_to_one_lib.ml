open Httpaf
open Lwt.Infix

let http_get = Http_client.http_get;;

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

let pick_session_mode user_input_promise =
  Lwt.bind user_input_promise (fun user_input ->
    match user_input with
      | "client" -> Lwt.return Mode.Client
      | "server" -> Lwt.return Mode.Server
      | unrecognised_mode -> Lwt.fail (Mode.Unrecognised (String.concat " " ["Unrecognised mode:"; unrecognised_mode])));;

let pick_session_mode_from_stdin = pick_session_mode (Lwt_io.read_line Lwt_io.stdin);;

module Client = struct
  exception MalformedSocket of string;;

  let get_server_socket user_input_promise =
    Lwt.bind user_input_promise (fun user_input ->
      let split = String.split_on_char ':' user_input in
      match split with
        | (host :: port :: []) -> Lwt.return (host, int_of_string port)
        | _ -> Lwt.fail (MalformedSocket (String.concat " " ["Couldn't parse hostname and port number from:"; user_input])));;

  let get_server_socket_from_stdin = get_server_socket (Lwt_io.read_line Lwt_io.stdin);;
end;;

exception ResponseNotReceived of string;;

let rec chat hostname port =
  print_string "> "; flush stdout;
  Lwt_io.read_line Lwt_io.stdin
  >>= fun message ->
  http_get hostname port (String.concat "=" ["/message?content"; message])
  >>= fun optional_response -> match optional_response with
    | None -> Lwt.fail (ResponseNotReceived "Didn't get an acknowledgement from chat partner")
    | Some (_, body) -> Lwt.bind (Lwt.return (print_endline body)) (fun () -> chat hostname port);;

let start_in_client_mode _ =
  print_endline "What's the socket of the server in the format host:port? (e.g. 'localhost:8080')";
  print_string "> "; flush stdout;
  Client.get_server_socket_from_stdin
  >>= fun (hostname, port) ->
  let startup_message = String.concat " " ["Running in client mode against server at host"; hostname; "on port"; Int.to_string port] in
  Lwt.bind (
    Lwt.return (print_endline startup_message))
    (fun () -> chat hostname port);;

module Server = struct
  exception MalformedPort of string;;

  let pick_port user_input_promise =
    Lwt.bind user_input_promise (fun user_input ->
      try
        let parsed_port = int_of_string user_input in
        Lwt.return parsed_port
      with
        | Failure _ -> Lwt.fail (MalformedPort (String.concat " " ["Couldn't parse port number from:"; user_input]))
        | e -> Lwt.fail e
    );;

  let pick_port_from_stdin _ = pick_port (Lwt.return (input_line stdin));;
end;;

let default_server_req_handler reqd =
  match Reqd.request reqd  with
  | { Request.meth = `GET; _ } ->
    let headers = Headers.of_list ["content-type", "application/json"; "connection", "close"] in
    Reqd.respond_with_string reqd (Response.create ~headers `OK) "Message receieved"
  | _ ->
    let headers = Headers.of_list [ "connection", "close" ] in
    Reqd.respond_with_string reqd (Response.create ~headers `Method_not_allowed) "";;

let start_in_server_mode _ =
  print_endline "Which port should this server run on? (e.g. '8081')";
  print_string "> "; flush stdout;
  Server.pick_port_from_stdin ()
  >>= (fun port_number ->
  let (forever, _) = Http_server.start_server port_number default_server_req_handler in
  let startup_message = String.concat " " ["Running in server mode on port"; Int.to_string port_number] in
  Lwt.bind (
    Lwt.return (print_endline startup_message))
    (fun () -> forever))

let start_one_on_one _ =
  print_endline "Pick a mode ('client' or 'server')";
  print_string "> "; flush stdout;
  Lwt_main.run (pick_session_mode_from_stdin
  >>= (fun mode ->
  match mode with
    | Mode.Client -> start_in_client_mode ()
    | Mode.Server -> start_in_server_mode ()
  ));;