open Httpaf
open Httpaf_lwt_unix
open Lwt.Infix
module Format = Caml.Format

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

let promise_of_string s =
  let (p : string Lwt.t), r = Lwt.wait () in
  Lwt.wakeup r s;
  p;;

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

let last_seven_in_response_body hostname =
  Lwt_unix.getaddrinfo hostname (Int.to_string 80) [Unix.(AI_FAMILY PF_INET)]
  >>= fun addresses ->
  let socket = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Lwt_unix.connect socket (Base.List.hd_exn addresses).Unix.ai_addr
  >>= fun () ->
  let finished, notify_finished = Lwt.wait () in
  let on_eof = Lwt.wakeup_later notify_finished in
  let response_body_reference = ref "" in
  let assign_to_reference s =
    response_body_reference := String.trim s
  in
  let response_handler _ response_body =
    let rec on_read bs ~off ~len =
      Bigstringaf.substring ~off ~len bs |> assign_to_reference;
      Body.schedule_read response_body ~on_read ~on_eof
    in
    Body.schedule_read response_body ~on_read ~on_eof
  in
  let error_handler error =
    let error =
      match error with
      | `Malformed_response err -> Format.sprintf "Malformed response: %s" err
      | `Invalid_response_body_length _ -> "Invalid body length"
      | `Exn exn -> Format.sprintf "Exn raised: %s" (Base.Exn.to_string exn)
    in
    Format.eprintf "Error handling response: %s\n%!" error
  in
  let headers = Headers.of_list [ "host", hostname ] in
  let request_body =
    Client.request
      ~error_handler
      ~response_handler
      socket
      (Request.create ~headers `GET "/")
  in
  Body.close_writer request_body;
  let last_seven_chars_in_response_body response_body_string =
    String.sub response_body_string (-7 + String.length response_body_string) 7 in
  Lwt.bind finished (fun () ->
    promise_of_string (last_seven_chars_in_response_body !response_body_reference));;