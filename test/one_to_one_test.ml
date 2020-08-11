open OUnit2;;
open Lwt.Infix
module Oto = One_to_one_lib;;

let test_http_get _ =
  let last_seven_in_response_body hostname port_number request_path =
    Oto.http_get hostname port_number request_path
    >>= fun r -> match r with
      | None -> Lwt.return None
      | Some (_, body) ->
        let last_seven_chars_in_response_body response_body_string =
          String.sub response_body_string (-7 + String.length response_body_string) 7 in
        Lwt.return (Some (last_seven_chars_in_response_body body))
  in
  let actual = (Lwt_main.run (last_seven_in_response_body "www.google.com" 80 "/")) in
  let expected = Some "</html>" in
  Assertions.assert_options_equal expected actual;;

let test_start_server_and_hit_it _ =
  let port = 8080 in
  let call_api =
    Lwt_unix.sleep 0.5
    >>= fun () ->
    Oto.http_get "localhost" port "/"
    >>= fun optional_pair ->
    match optional_pair with
      | None -> Lwt.fail (OUnitTest.OUnit_failure "Didn't get a valid response")
      | Some _ -> Lwt.return ()
  in
  Oto.run_server_during_lwt_task port Oto.Server.chat_req_handler call_api;;

let test_pick_session_mode _ =
  let simulate_pick_session_mode user_input = (Lwt_main.run (Oto.Mode.pick (Lwt.return user_input))) in
  assert_equal Oto.Mode.Client (simulate_pick_session_mode "client");
  assert_equal Oto.Mode.Server (simulate_pick_session_mode "server");
  assert_raises (Oto.Mode.Unrecognised "Unrecognised mode: nonsense")
    (fun() -> simulate_pick_session_mode "nonsense")

let test_client_requests_server_socket _ =
  let simulate_get_server_socket user_input = (Lwt_main.run (Oto.Client.get_server_socket (Lwt.return user_input))) in
  Assertions.assert_socket_pair_equal ("localhost", 8080) (simulate_get_server_socket "localhost:8080");
  Assertions.assert_socket_pair_equal ("www.my-ec2-instance.com", 8081) (simulate_get_server_socket "www.my-ec2-instance.com:8081");
  assert_raises (Oto.Client.MalformedSocket "Couldn't parse hostname and port number from: nonsense")
    (fun() -> simulate_get_server_socket "nonsense");;

let test_server_requests_port_to_run_on _ =
  let simulate_get_server_port user_input = (Lwt_main.run (Oto.Server.pick_port (Lwt.return user_input))) in
  assert_equal 8080 (simulate_get_server_port "8080");
  assert_raises (Oto.Server.MalformedPort "Couldn't parse port number from: nonsense")
    (fun() -> simulate_get_server_port "nonsense");;

exception Timeout of string;;

let dummy_log _ = ();;

let test_server_exits_after_user_types_slash_exit _ =
  let server_run = Oto.Server.run [Lwt.return "8081"; Lwt.return "/exit"] dummy_log in
  let timeout = Lwt.bind (Lwt_unix.sleep 0.5) (fun () -> Lwt.fail (Timeout "Server didn't start and then exit based on user input")) in
  Lwt_main.run (Lwt.pick [server_run; timeout]);;

let suite =
  "OneToOneTest" >::: [
    "test_http_get" >:: test_http_get;
    "test_start_server_and_hit_it" >:: test_start_server_and_hit_it;
    "test_pick_session_mode" >:: test_pick_session_mode;
    "test_client_requests_server_socket" >:: test_client_requests_server_socket;
    "test_server_requests_port_to_run_on" >:: test_server_requests_port_to_run_on;
    "test_server_exits_after_user_types_slash_exit" >:: test_server_exits_after_user_types_slash_exit
  ];;

run_test_tt_main suite