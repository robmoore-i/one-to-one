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

let shell_output command =
  let ic, oc = Unix.open_process command in
  let buf = Buffer.create 16 in
  (try
     while true do
       Buffer.add_channel buf ic 1
     done
   with End_of_file -> ());
  let _ = Unix.close_process (ic, oc) in
  String.trim (Buffer.contents buf);;

exception MalformedSocket of string;;

exception ResponseNotReceived of string;;

module Client = struct
  let get_server_socket user_input_promise =
    Lwt.bind user_input_promise (fun user_input ->
      let split = String.split_on_char ':' user_input in
      match split with
        | (host :: port :: []) -> Lwt.return (host, int_of_string port)
        | _ -> Lwt.fail (MalformedSocket (String.concat " " ["Couldn't parse hostname and port number from:"; user_input])));;

  let get_server_socket_from_stdin = get_server_socket (Lwt_io.read_line Lwt_io.stdin);;

  let chat_http_request_handler log reqd =
    match Reqd.request reqd  with
    | { Request.meth = `GET; target; _ } ->
      let headers = Headers.of_list ["content-type", "application/json"; "connection", "close"] in
      let target_expected_prefix_length = String.length "/message?content=" in
      let message_content = String.sub target target_expected_prefix_length ((String.length target) - target_expected_prefix_length) in
      log (String.concat " " ["\n>c>"; message_content; "\nc> "]);
      Reqd.respond_with_string reqd (Response.create ~headers `OK) "confirmed"
    | _ ->
      let headers = Headers.of_list [ "connection", "close" ] in
      Reqd.respond_with_string reqd (Response.create ~headers `Method_not_allowed) "";;

  let public_ip_address _ = shell_output "dig +short myip.opendns.com @resolver1.opendns.com";;

  (* This function is partially applied to produce a function of the signature
     string -> unit, whose job is to send chat messages. This makes the
     message-sending functionality injectable, and therefore both testable and
     swappable. *)
  let http_chat_msg_sender client_port server_hostname server_port msg =
    let client_host = if "localhost" = server_hostname then "localhost" else public_ip_address () in
    http_get server_hostname server_port (Printf.sprintf "/message?content=%s&reply_socket=%s:%s" msg client_host (Int.to_string client_port))
    >>= fun optional_response -> match optional_response with
      | None -> Lwt.return (Printf.sprintf "Message not acknowledged by chat partner (server at %s:%s) - presumably it was not recieved..." server_hostname (Int.to_string server_port))
      | Some (_, body) -> Lwt.return (String.concat "" [body; "\n"]);;

  let rec chat log user_input_promises i send_msg =
    log "\nc> ";
    nth_user_input user_input_promises i
    >>= fun user_input ->
    if user_input = "/exit"
    then Lwt.return (log "\nExiting\n")
    else Lwt.bind (send_msg user_input) (fun acknowledgement_msg ->
      log acknowledgement_msg;
      chat log user_input_promises (i + 1) send_msg);;

  let run log user_input_promises chat_msg_sender port_determiner =
    log "What's the socket of the server in the format host:port? (e.g. 'localhost:8080')\n> ";
    get_server_socket (nth_user_input user_input_promises 0)
    >>= fun (server_hostname, server_port) ->
    let client_port = port_determiner () in
    let server_reference_promise = Http_server.start_server client_port (chat_http_request_handler log) in
    let send_msg = chat_msg_sender client_port server_hostname server_port in
    let startup_message = String.concat " " ["Running in client mode against server at host"; server_hostname; "on port"; Int.to_string server_port; "\n"] in
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

  (* This function takes a string and drops the leading '/message?content='.
     Then it finds the last instance of 'reply_socket=' and parses the following text as a socket (host:port).
     The remaining text in the middle is considered the message content.
     This information is then compiled into a triple of the form (msg, reply_host, reply_port) *)
  let parse_http_target http_target =
    let target_expected_prefix_length = String.length "/message?content=" in
    let truncate s chop_size = String.sub s chop_size ((String.length s) - chop_size) in
    let truncated_target = truncate http_target target_expected_prefix_length in
    let last_occurance = Str.search_backward (Str.regexp "&reply_socket=") truncated_target (String.length truncated_target) in
    let message_content = String.sub truncated_target 0 last_occurance in
    let socket_pair = truncate truncated_target (last_occurance + (String.length "&reply_socket=")) in
    let split = String.split_on_char ':' socket_pair in
    match split with
      | (host :: port :: []) -> (message_content, host, int_of_string port)
      | _ -> raise (MalformedSocket (String.concat " " ["Couldn't parse client's hostname and port number from:"; socket_pair]));;

  let chat_http_request_handler log client_socket_pair_reference reqd =
    match Reqd.request reqd  with
    | { Request.meth = `GET; target; _ } ->
      let headers = Headers.of_list ["content-type", "application/json"; "connection", "close"] in
      let (message_content, client_host, client_port) = parse_http_target target in
      client_socket_pair_reference := Some (client_host, client_port);
      log (String.concat " " ["\n>s>"; message_content; "\ns> "]);
      Reqd.respond_with_string reqd (Response.create ~headers `OK) "confirmed"
    | _ ->
      let headers = Headers.of_list [ "connection", "close" ] in
      Reqd.respond_with_string reqd (Response.create ~headers `Method_not_allowed) "";;

  (* This function is partially applied to produce a function of the signature
     string -> unit, whose job is to send chat messages. This makes the
     message-sending functionality injectable, and therefore both testable and
     swappable. *)
  let http_chat_msg_sender client_socket_pair_reference msg =
    match !client_socket_pair_reference with
      | None -> Lwt.return "Can't send message because there isn't a connected chat partner"
      | Some (host, port) ->
        http_get host port (Printf.sprintf "/message?content=%s" msg)
        >>= fun optional_response -> match optional_response with
          | None -> Lwt.return (Printf.sprintf "Message not acknowledged by chat partner (client at %s:%s) - presumably it was not recieved..." host (Int.to_string port))
          | Some (_, body) -> Lwt.return (String.concat "" [body; "\n"]);;

  let rec chat log user_input_promises i msg_sender =
    log "\ns> ";
    nth_user_input user_input_promises i
    >>= fun user_input ->
    if user_input = "/exit"
    then Lwt.return (log "\nExiting\n")
    else
    Lwt.bind (msg_sender user_input) (fun acknowledgement_msg ->
      log acknowledgement_msg;
      chat log user_input_promises (i + 1) msg_sender);;


  let run log user_input_promises msg_sender =
    log "Which port should this server run on? (e.g. '8081')\n> ";
    pick_port (nth_user_input user_input_promises 0)
    >>= fun port_number ->
    let client_socket_pair_reference = ref None in
    let server_reference_promise = Http_server.start_server port_number (chat_http_request_handler log client_socket_pair_reference) in
    let startup_message = String.concat " " ["Running in server mode on port"; Int.to_string port_number;"\n"] in
    log startup_message;
    Http_server.schedule_server_shutdown
      (chat log user_input_promises 1 (msg_sender client_socket_pair_reference))
      server_reference_promise;;
end;;

(* Ports 50,000 - 60,000 are generally free for use. Needless to say, this is
   an imperfect implementation. An improvement would be to have this function
   try to listen on the randomly selected port to check that it's free before
   returning it. It would retry until finding a free port to listen on. *)
let random_port_determiner _ = 50000 + (Random.int 10000);;

let start_one_on_one _ =
  default_log "Pick a mode ('client' or 'server')\n> ";
  Lwt_main.run (Mode.pick_from_stdin
  >>= (fun mode ->
  match mode with
    | Mode.Client -> Client.run default_log [] Client.http_chat_msg_sender random_port_determiner
    | Mode.Server -> Server.run default_log [] Server.http_chat_msg_sender
  ));;