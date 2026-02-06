# FUNCTIONAL

## Pattern Matching Over Conditionals

```ocaml
(* avoid *)
if x = 0 then "zero" else if x > 0 then "positive" else "negative"

(* prefer *)
match x with 0 -> "zero" | n when n > 0 -> "positive" | _ -> "negative"
```

## Pipelines Over Sequences

```ocaml
(* avoid *)
let trimmed = String.trim input in
let lines = String.split_on_char '\n' trimmed in
List.map process lines

(* prefer *)
input |> String.trim |> String.split_on_char '\n' |> List.map process
```

## Immutable Over Mutable

```ocaml
(* avoid *)
let results = ref [] in
List.iter (fun x -> if p x then results := x :: !results) items;
!results

(* prefer *)
items |> List.filter p
```

## Option Over Exceptions

```ocaml
(* avoid *)
try db_lookup id with Not_found -> null

(* prefer *)
match db_lookup id with user -> Some user | exception Not_found -> None
```

## Types That Prevent Invalid States

```ocaml
(* avoid *)
type user = { email: string; verified: bool }

(* prefer *)
type email = Unverified of string | Verified of string
type user = { email: email }
```

## Small Functions That Compose

```ocaml
(* avoid: big function with loops and refs *)

(* prefer *)
let is_header s = String.length s > 0 && s.[0] = '#'
path |> read_file |> String.split_on_char '\n' |> List.filter is_header
```

## Recursion/Fold Over Loops

```ocaml
(* avoid *)
let total = ref 0 in for i = 0 to n do total := !total + i done; !total

(* prefer *)
List.fold_left (+) 0 items
```

## Total Functions

```ocaml
(* avoid *)
let head = function x :: _ -> x | [] -> failwith "empty"

(* prefer *)
let head = function x :: _ -> Some x | [] -> None
```

## Red Flags

| Smell | Fix |
|-------|-----|
| `ref` | fold/recursion |
| `for`/`while` | List.map/fold |
| `if`/`else` chains | pattern match |
| `try`/`with` control flow | Option/Result |
| deeply nested | pipeline |
