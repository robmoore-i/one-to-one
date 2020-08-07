open Httpaf
open Httpaf_lwt_unix
open Lwt.Infix
module Format = Caml.Format

let using_socket hostname port_number =
  Lwt.return (Unix.getaddrinfo hostname (Int.to_string port_number) [Unix.(AI_FAMILY PF_INET)])
  >>= fun addresses ->
  let socket = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Lwt_unix.connect socket (Base.List.hd_exn addresses).Unix.ai_addr
  >>= fun () -> Lwt.return socket;;

let default_error_handler error =
    let error =
      match error with
      | `Malformed_response err -> Format.sprintf "Malformed response: %s" err
      | `Invalid_response_body_length _ -> "Invalid body length"
      | `Exn exn -> Format.sprintf "Exn raised: %s" (Base.Exn.to_string exn)
    in
    Format.eprintf "Error handling response: %s\n%!" error;;

let default_headers hostname =
  Headers.of_list ["host", hostname];;

let last_seven_in_response_body hostname port_number =
  using_socket hostname port_number
  >>= fun socket ->
  let finished, notify_finished = Lwt.wait () in
  let on_eof = Lwt.wakeup_later notify_finished in
  let response_body_reference = ref "---not yet filled in---" in
  let assign_to_reference s =
    response_body_reference := String.trim s
  in
  let response_handler _response response_body =
    (* For debugging: Format.fprintf Format.std_formatter "%a\n%!" Response.pp_hum _response; *)
    let rec on_read bs ~off ~len =
      Bigstringaf.substring ~off ~len bs |> assign_to_reference;
      Body.schedule_read response_body ~on_read ~on_eof
    in
    Body.schedule_read response_body ~on_read ~on_eof
  in
  let request_body =
    Client.request
      ~error_handler:default_error_handler
      ~response_handler
      socket
      (Request.create ~headers:(default_headers hostname) `GET "/")
  in
  Body.close_writer request_body;
  let last_seven_chars_in_response_body response_body_string =
    String.sub response_body_string (-7 + String.length response_body_string) 7 in
  let timeout = Lwt_unix.sleep 3.0 in
  Lwt.bind (Lwt.pick [finished; timeout]) (fun () ->
    Lwt.return (last_seven_chars_in_response_body !response_body_reference));;