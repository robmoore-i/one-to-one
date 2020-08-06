open One_to_one_lib;;
open OUnit2;;

let test_average _ =
  assert_equal 2.5 (average 2.0 3.0);;

let suite =
  "AverageTest" >::: [
    "test_average" >:: test_average
  ];;

run_test_tt_main suite