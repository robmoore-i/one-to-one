open OUnit2;;

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

let assert_socket_pair_equal (expectedHost, expectedPort) (actualHost, actualPort) =
  let print_endline_socket_pair (host, port) = print_endline (String.concat " " ["("; host; ","; Int.to_string port; ")"]) in
  try assert_equal expectedHost actualHost; assert_equal expectedPort actualPort
  with e ->
    Format.eprintf "\nError: %s\n%!" (Caml.Format.sprintf "Exn raised: %s" (Base.Exn.to_string e));
    print_string "Expected: ";
    print_endline_socket_pair (expectedHost, expectedPort);
    print_string "Actual:   ";
    print_endline_socket_pair (actualHost, actualPort);
    raise e;;

let assert_string_equal expected actual =
  try assert_equal expected actual
  with e ->
    Format.eprintf "\nError: %s\n%!" (Caml.Format.sprintf "Exn raised: %s" (Base.Exn.to_string e));
    print_string "Expected: ";
    print_endline expected;
    print_string "Actual:   ";
    print_endline actual;
    raise e;;