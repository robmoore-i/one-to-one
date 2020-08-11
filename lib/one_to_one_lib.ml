open Httpaf
open Lwt.Infix

let http_get = Http_client.http_get;;

let default_log s = print_string s; flush stdout

(* If custom input is provided (i.e. in a test or from some other input
   source) then use that. Otherwise, read input from stdin.

   You'll notice this function reads from stdin in two ways. This is because
   for the first read, I've found that using the Lwt function ignores the
   first input, which is a buggy, unpleasant experience. I don't have an
   explanation for why Lwt behaves in this way. At the same time however,
   using the blocking console read causes the server (which should really be
   running in a different thread) to stop serving requests. Empirically, I've
   found that the below usage arrangement provides the expected user
   experience.
*)
let nth_user_input user_input_promises i =
  match List.nth_opt user_input_promises i with
    | Some p -> p
    | None ->
      match i with
        | 0 -> Lwt.return (input_line stdin)
        | 1 ->
          default_log "Press enter to continue > ";
          Lwt_io.read_line Lwt_io.stdin
        | _ -> Lwt_io.read_line Lwt_io.stdin;;

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

let chat_http_request_handler log reqd =
  match Reqd.request reqd  with
  | { Request.meth = `GET; target; _ } ->
    let headers = Headers.of_list ["content-type", "application/json"; "connection", "close"] in
    let target_expected_prefix_length = String.length "/message?content=" in
    let message_content = String.sub target target_expected_prefix_length ((String.length target) - target_expected_prefix_length) in
    log (String.concat " " ["> >"; message_content; "\n"]);
    Reqd.respond_with_string reqd (Response.create ~headers `OK) "confirmed"
  | _ ->
    let headers = Headers.of_list [ "connection", "close" ] in
    Reqd.respond_with_string reqd (Response.create ~headers `Method_not_allowed) "";;

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

  (* This function is partially applied to produce a function of the signature
     string -> unit, whose job is to send chat messages. This makes the
     message-sending functionality injectable, and therefore both testable and
     swappable. *)
  let http_chat_msg_sender hostname port msg =
    http_get hostname port (String.concat "=" ["/message?content"; msg])
    >>= fun optional_response -> match optional_response with
      | None -> Lwt.fail (ResponseNotReceived "Didn't get an acknowledgement from chat partner")
      | Some (_, body) -> Lwt.return (String.concat "" [body; "\n"]);;

  let rec chat log user_input_promises i send_msg =
    log "> ";
    nth_user_input user_input_promises i
    >>= fun user_input ->
    if user_input = "/exit"
    then Lwt.return (log "Exiting\n")
    else Lwt.bind (send_msg user_input) (fun acknowledgement_msg ->
      log acknowledgement_msg;
      chat log user_input_promises (i + 1) send_msg);;

  let run user_input_promises log chat_msg_sender port_determiner =
    log "What's the socket of the server in the format host:port? (e.g. 'localhost:8080')\n> ";
    get_server_socket (nth_user_input user_input_promises 0)
    >>= fun (hostname, port) ->
    let server_reference_promise = Http_server.start_server (port_determiner ()) (chat_http_request_handler log) in
    let send_msg = chat_msg_sender hostname port in
    let startup_message = String.concat " " ["Running in client mode against server at host"; hostname; "on port"; Int.to_string port; "\n"] in
    log startup_message;
    Http_server.schedule_server_shutdown
      (chat log user_input_promises 1 send_msg)
      server_reference_promise;;
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

  let rec chat log user_input_promises i =
    nth_user_input user_input_promises i
    >>= fun user_input ->
    if user_input = "/exit"
    then Lwt.return (log "Exiting\n")
    else
    chat log user_input_promises (i + 1);;

  let run user_input_promises log =
    log "Which port should this server run on? (e.g. '8081')\n> ";
    pick_port (nth_user_input user_input_promises 0)
    >>= fun port_number ->
    let server_reference_promise = Http_server.start_server port_number (chat_http_request_handler log) in
    let startup_message = String.concat " " ["Running in server mode on port"; Int.to_string port_number;"\n"] in
    log startup_message;
    Http_server.schedule_server_shutdown
      (chat log user_input_promises 1)
      server_reference_promise;;
end;;

let random_port_determiner _ = 50051

let start_one_on_one _ =
  default_log "Pick a mode ('client' or 'server')\n> ";
  Lwt_main.run (Mode.pick_from_stdin
  >>= (fun mode ->
  match mode with
    | Mode.Client -> Client.run [] default_log Client.http_chat_msg_sender random_port_determiner
    | Mode.Server -> Server.run [] default_log
  ));;