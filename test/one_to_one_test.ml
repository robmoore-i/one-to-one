open OUnit2;;
module Oto = One_to_one_lib;;

let test_average _ =
  assert_equal 2.5 (Oto.average 2.0 3.0);;

let test_square_plus_one _ =
  assert_equal 5 (Oto.square_plus_one 2);;

let test_cube_plus_one _ =
  assert_equal 9 (Oto.cube_plus_one 2);;

let suite =
  "AverageTest" >::: [
    "test_average" >:: test_average;
    "test_square_plus_one" >:: test_square_plus_one;
    "test_cube_plus_one" >:: test_cube_plus_one
  ];;

run_test_tt_main suite