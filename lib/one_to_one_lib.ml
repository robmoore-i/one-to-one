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

  let pick user_input_promise =
    Lwt.bind user_input_promise (fun user_input ->
      match user_input with
        | "client" -> Lwt.return Client
        | "server" -> Lwt.return Server
        | unrecognised_mode -> Lwt.fail (Unrecognised (String.concat " " ["Unrecognised mode:"; unrecognised_mode])));;

  let pick_from_stdin = pick (Lwt_io.read_line Lwt_io.stdin);;
end;;

module Client = struct
  exception MalformedSocket of string;;

  let get_server_socket user_input_promise =
    Lwt.bind user_input_promise (fun user_input ->
      let split = String.split_on_char ':' user_input in
      match split with
        | (host :: port :: []) -> Lwt.return (host, int_of_string port)
        | _ -> Lwt.fail (MalformedSocket (String.concat " " ["Couldn't parse hostname and port number from:"; user_input])));;

  let get_server_socket_from_stdin = get_server_socket (Lwt_io.read_line Lwt_io.stdin);;

  exception ResponseNotReceived of string;;

  let rec chat hostname port =
    print_string "> "; flush stdout;
    Lwt_io.read_line Lwt_io.stdin
    >>= fun message ->
    http_get hostname port (String.concat "=" ["/message?content"; message])
    >>= fun optional_response -> match optional_response with
      | None -> Lwt.fail (ResponseNotReceived "Didn't get an acknowledgement from chat partner")
      | Some (_, body) -> Lwt.bind (Lwt.return (print_endline body)) (fun () -> chat hostname port);;

  let start _ =
    print_endline "What's the socket of the server in the format host:port? (e.g. 'localhost:8080')";
    print_string "> "; flush stdout;
    get_server_socket_from_stdin
    >>= fun (hostname, port) ->
    let startup_message = String.concat " " ["Running in client mode against server at host"; hostname; "on port"; Int.to_string port] in
    Lwt.bind (
      Lwt.return (print_endline startup_message))
      (fun () -> chat hostname port);;
end;;

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

  let chat_req_handler reqd =
    match Reqd.request reqd  with
    | { Request.meth = `GET; target; _ } ->
      let headers = Headers.of_list ["content-type", "application/json"; "connection", "close"] in
      let target_expected_prefix_length = String.length "/message?content=" in
      print_endline (String.concat " " ["> >"; (String.sub target target_expected_prefix_length ((String.length target) - target_expected_prefix_length))]);
      Reqd.respond_with_string reqd (Response.create ~headers `OK) "Message receieved"
    | _ ->
      let headers = Headers.of_list [ "connection", "close" ] in
      Reqd.respond_with_string reqd (Response.create ~headers `Method_not_allowed) "";;

  let rec chat user_input_promise =
    user_input_promise
    >>= fun user_input ->
    if user_input = "exit"
    then Lwt.return (print_endline "Exiting")
    else chat user_input_promise;;

  let run_with_user_input user_input_promises =
    print_endline "Which port should this server run on? (e.g. '8081')";
    print_string "> "; flush stdout;
    pick_port (List.nth user_input_promises 0)
    >>= fun port_number ->
    let server_reference_promise = Http_server.start_server port_number chat_req_handler in
    let startup_message = String.concat " " ["Running in server mode on port"; Int.to_string port_number] in
    Lwt.bind server_reference_promise (fun _ -> Lwt.return (print_endline startup_message))
    >>= fun () ->
    chat (List.nth user_input_promises 1);;

  let start _ =
    print_endline "Which port should this server run on? (e.g. '8081')";
    print_string "> "; flush stdout;
    pick_port_from_stdin ()
    >>= fun port_number ->
    let server_reference_promise = Http_server.start_server port_number chat_req_handler in
    let startup_message = String.concat " " ["Running in server mode on port"; Int.to_string port_number] in
    Lwt.bind server_reference_promise (fun _ -> Lwt.return (print_endline startup_message))
    >>= fun () ->
    let forever, _ = Lwt.wait () in
    forever;;
end;;

let start_one_on_one _ =
  print_endline "Pick a mode ('client' or 'server')";
  print_string "> "; flush stdout;
  Lwt_main.run (Mode.pick_from_stdin
  >>= (fun mode ->
  match mode with
    | Mode.Client -> Client.start ()
    | Mode.Server -> Server.start ()
  ));;