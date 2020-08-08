open Httpaf
open Httpaf_lwt_unix
open Lwt.Infix
module Format = Caml.Format

let default_error_handler ?request:_ error start_response =
  let response_body = start_response Headers.empty in
  begin match error with
    | `Exn exn ->
      Body.write_string response_body (Base.Exn.to_string exn);
      Body.write_string response_body "\n";
    | #Status.standard as error ->
      Body.write_string response_body (Status.default_reason_phrase error)
  end;
  Body.close_writer response_body;;

let start_server port req_handler  =
  let listen_address = Unix.(ADDR_INET (inet_addr_loopback, port)) in
  let request_handler (_ : Unix.sockaddr) = req_handler in
  let error_handler (_ : Unix.sockaddr) = default_error_handler in
  let server_reference = ref None in
  let assign_to_server_reference s = server_reference := Some s in
  Lwt.async (fun () ->
    Lwt_io.establish_server_with_client_socket
      listen_address
      (Server.create_connection_handler ~request_handler ~error_handler)
    >|= fun (server : Lwt_io.server) ->
      assign_to_server_reference server;
      (* For debugging:
         print_string "Listening on port ";
         print_endline (Int.to_string port)
      *)
      );
  let forever, _ = Lwt.wait () in
  (forever, server_reference);;

let run_server_forever port req_handler =
  let (forever, _) = start_server port req_handler in
  Lwt_main.run forever;;

let run_server_during_lwt_task port req_handler lwt_task =
  let (forever, server_reference) = start_server port req_handler in
  Lwt_main.run (Lwt.bind (Lwt.pick [forever; lwt_task]) (fun () ->
    match !server_reference with
      | None -> Lwt.return (print_endline "Something broke")
      | Some reference -> Lwt_io.shutdown_server reference));;

let run_server_for_n_seconds port req_handler seconds =
  run_server_during_lwt_task port req_handler (Lwt_unix.sleep seconds);;