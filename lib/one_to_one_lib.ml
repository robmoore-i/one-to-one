let average a b =
  (a +. b) /. 2.0;;

let square_plus_one a =
  let a_squared = a * a in
  a_squared + 1;;

let cube_plus_one a =
  let accumulator = ref 1 in
  (accumulator := !accumulator + (a * a * a));
  !accumulator;;