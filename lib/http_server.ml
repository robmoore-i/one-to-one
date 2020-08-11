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
  Lwt_io.establish_server_with_client_socket
    listen_address
    (Server.create_connection_handler ~request_handler ~error_handler)
  >|= fun (server : Lwt_io.server) ->
  assign_to_server_reference server;
  (* For debugging:
     print_string "Listening on port ";
     print_endline (Int.to_string port)
  *)
  >>= fun _ ->
  Lwt.return server_reference;;

(* Shuts down the server after the resolution of the promise P. *)
let schedule_server_shutdown p optional_server_reference_promise =
  optional_server_reference_promise
  >>= fun optional_server_reference ->
  Lwt.bind p (fun () ->
    match !optional_server_reference with
      | None -> Lwt.return (print_endline "Something broke")
      | Some reference ->
        (*print_endline "Shutting down";*)
        Lwt_io.shutdown_server reference);;
