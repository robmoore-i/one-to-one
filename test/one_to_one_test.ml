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

let assert_options_equal expected actual =
  let print_endline_option o = match o with
    | Some data -> print_endline (String.concat " " ["Some"; data])
    | None -> print_endline "None"
  in
  try assert_equal expected actual
  with e ->
    Format.eprintf "\nError: %s\n%!" (Caml.Format.sprintf "Exn raised: %s" (Base.Exn.to_string e));
    print_string "Expected: ";
    print_endline_option expected;
    print_string "Actual:   ";
    print_endline_option actual;
    raise e;;

let test_last_seven_in_response_body _ =
  let actual = (Lwt_main.run (Oto.last_seven_in_response_body "www.google.com" 80 "/")) in
  let expected = Some "</html>" in
  assert_options_equal expected actual;;

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
      | None -> Lwt.fail (OUnitTest.OUnit_failure "Fucked it")
      | Some _ -> Lwt.return ()
  in
  Oto.run_server_during_lwt_task port call_api;;

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
    "test_start_server_and_hit_it" >:: test_start_server_and_hit_it
  ];;

run_test_tt_main suite