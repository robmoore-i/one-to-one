open OUnit2;;
open Lwt.Infix
module Oto = One_to_one_lib;;

let test_average _ =
  assert_equal 2.5 (Oto.average 2.0 3.0);;

let test_square_plus_one _ =
  assert_equal 5 (Oto.square_plus_one 2);;

let test_cube_plus_one _ =
  assert_equal 9 (Oto.cube_plus_one 2);;

let test_first_times_last _ =
  assert_equal 0 (Oto.first_times_last []);
  assert_equal 0 (Oto.first_times_last [2]);
  assert_equal 6 (Oto.first_times_last [2; 3]);
  assert_equal 21 (Oto.first_times_last [3; 5; 7]);;

let test_read_first_line _ =
  assert_equal "This file contains some text" (Oto.read_first_line "test_file.txt");;

let test_read_first_line_lwt _ =
  assert_equal "This file contains some text" (Lwt_main.run (Oto.read_first_line_lwt "test_file.txt"));;

let test_last_seven_in_response_body _ =
  let actual = (Lwt_main.run (Oto.last_seven_in_response_body "www.google.com" 80 "/")) in
  let expected = Some "</html>" in
  Assertions.assert_options_equal expected actual;;

let test_powers_of_two_and_three _ =
  let (square, cube) = Oto.powers_of_two_and_three 3 in
  assert_equal 9 square;
  assert_equal 27 cube;;

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
  Oto.run_server_during_lwt_task port call_api;;

let test_pick_session_mode _ =
  let simulate_pick_session_mode user_input = (Lwt_main.run (Oto.pick_session_mode (Lwt.return user_input))) in
  assert_equal Oto.Mode.Client (simulate_pick_session_mode "client");
  assert_equal Oto.Mode.Server (simulate_pick_session_mode "server");
  assert_raises (Oto.Mode.Unrecognised "Unrecognised mode: nonsense")
    (fun() -> simulate_pick_session_mode "nonsense")

let test_client_requests_server_socket _ =
  let simulate_get_server_socket user_input = (Lwt_main.run (Oto.Client.get_server_socket (Lwt.return user_input))) in
  Assertions.assert_socket_pair_equal ("localhost", 8080) (simulate_get_server_socket "localhost:8080");
  Assertions.assert_socket_pair_equal ("www.my-ec2-instance.com", 8081) (simulate_get_server_socket "www.my-ec2-instance.com:8081");
  assert_raises (Oto.Client.MalformedSocket "Couldn't parse hostname and port number from: nonsense")
    (fun() -> simulate_get_server_socket "nonsense")

let suite =
  "OneToOneTest" >::: [
    "test_average" >:: test_average;
    "test_square_plus_one" >:: test_square_plus_one;
    "test_cube_plus_one" >:: test_cube_plus_one;
    "test_first_times_last" >:: test_first_times_last;
    "test_read_first_line" >:: test_read_first_line;
    "test_read_first_line_lwt" >:: test_read_first_line_lwt;
    "test_last_seven_in_response_body" >:: test_last_seven_in_response_body;
    "test_powers_of_two_and_three" >:: test_powers_of_two_and_three;
    "test_start_server_and_hit_it" >:: test_start_server_and_hit_it;
    "test_pick_session_mode" >:: test_pick_session_mode;
    "test_client_requests_server_socket" >:: test_client_requests_server_socket
  ];;

run_test_tt_main suite