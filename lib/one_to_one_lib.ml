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
          | [] -> 0 in
      h * (last r)
    | [] -> 0

