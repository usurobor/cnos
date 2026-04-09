(** cn_package_test: ppx_expect tests for the pure package model
    extracted from cn_deps.ml in v3.38.0 (#182 Move 2 first slice).

    The module under test (`Cn_package`) owns the canonical type
    definitions for `manifest_dep`, `locked_dep`, `manifest`,
    `lockfile`, `index_entry`, `package_index` plus their pure
    JSON serialization, `parse_package_index`, `lookup_index`,
    and `is_first_party`. No IO.

    Tests:
    R1  manifest_dep round-trip through JSON
    R2  locked_dep round-trip through JSON
    R3  manifest record JSON shape (schema + profile + packages)
    R4  lockfile record JSON shape (schema + packages)
    P1  parse_package_index on a valid payload yields expected entries
    P2  parse_package_index on empty payload yields empty entries
    P3  parse_package_index ignores malformed version entries
    L1  lookup_index hit
    L2  lookup_index miss
    F1  is_first_party accepts cnos.* names
    F2  is_first_party rejects other names and short strings *)

(* === R1: manifest_dep JSON round-trip === *)

let%expect_test "R1 manifest_dep JSON round-trip" =
  let original : Cn_package.manifest_dep =
    { name = "cnos.core"; version = "3.37.0" } in
  let json = Cn_package.manifest_dep_to_json original in
  (match Cn_package.parse_manifest_dep json with
   | None -> print_endline "parse failed"
   | Some round_tripped ->
       Printf.printf "name=%s version=%s match=%b\n"
         round_tripped.name round_tripped.version
         (round_tripped.name = original.name
          && round_tripped.version = original.version));
  [%expect {| name=cnos.core version=3.37.0 match=true |}]

(* === R2: locked_dep JSON round-trip === *)

let%expect_test "R2 locked_dep JSON round-trip" =
  let original : Cn_package.locked_dep =
    { name = "cnos.eng"; version = "3.37.0"; sha256 = "deadbeef" } in
  let json = Cn_package.locked_dep_to_json original in
  (match Cn_package.parse_locked_dep json with
   | None -> print_endline "parse failed"
   | Some r ->
       Printf.printf "name=%s version=%s sha256=%s match=%b\n"
         r.name r.version r.sha256
         (r.name = original.name
          && r.version = original.version
          && r.sha256 = original.sha256));
  [%expect {|
    name=cnos.eng version=3.37.0 sha256=deadbeef match=true |}]

(* === R3: manifest record JSON shape === *)

let%expect_test "R3 manifest record constructs and reads fields" =
  let m : Cn_package.manifest = {
    schema = "cn.deps.v1";
    profile = "engineer";
    packages = [
      { name = "cnos.core"; version = "3.37.0" };
      { name = "cnos.eng";  version = "3.37.0" };
    ];
  } in
  Printf.printf "schema=%s\n" m.schema;
  Printf.printf "profile=%s\n" m.profile;
  Printf.printf "pkg_count=%d\n" (List.length m.packages);
  List.iter (fun (d : Cn_package.manifest_dep) ->
    Printf.printf "  - %s@%s\n" d.name d.version) m.packages;
  [%expect {|
    schema=cn.deps.v1
    profile=engineer
    pkg_count=2
      - cnos.core@3.37.0
      - cnos.eng@3.37.0 |}]

(* === R4: lockfile record JSON shape === *)

let%expect_test "R4 lockfile record constructs and reads fields" =
  let l : Cn_package.lockfile = {
    schema = "cn.lock.v2";
    packages = [
      { name = "cnos.core"; version = "3.37.0"; sha256 = "abc123" };
    ];
  } in
  Printf.printf "schema=%s\n" l.schema;
  Printf.printf "pkg_count=%d\n" (List.length l.packages);
  List.iter (fun (d : Cn_package.locked_dep) ->
    Printf.printf "  - %s@%s sha256=%s\n" d.name d.version d.sha256) l.packages;
  [%expect {|
    schema=cn.lock.v2
    pkg_count=1
      - cnos.core@3.37.0 sha256=abc123 |}]

(* === P1: parse_package_index on a valid payload === *)

let%expect_test "P1 parse_package_index valid payload" =
  let payload =
    {|{
      "schema": "cn.package-index.v1",
      "packages": {
        "cnos.core": {
          "3.37.0": {
            "url": "https://example.com/cnos.core-3.37.0.tar.gz",
            "sha256": "aaaa1111"
          }
        },
        "cnos.eng": {
          "3.37.0": {
            "url": "https://example.com/cnos.eng-3.37.0.tar.gz",
            "sha256": "bbbb2222"
          }
        }
      }
    }|}
  in
  (match Cn_json.parse payload with
   | Error msg -> Printf.printf "json-parse-error: %s\n" msg
   | Ok json ->
       let idx = Cn_package.parse_package_index json in
       Printf.printf "schema=%s\n" idx.index_schema;
       Printf.printf "entry_count=%d\n" (List.length idx.index_entries);
       (* Sort by name for deterministic output *)
       let sorted =
         List.sort (fun ((n1, _), _) ((n2, _), _) -> compare n1 n2)
           idx.index_entries
       in
       List.iter (fun ((n, v), (e : Cn_package.index_entry)) ->
         Printf.printf "  - %s@%s url=%s sha256=%s\n"
           n v e.ie_url e.ie_sha256) sorted);
  [%expect {|
    schema=cn.package-index.v1
    entry_count=2
      - cnos.core@3.37.0 url=https://example.com/cnos.core-3.37.0.tar.gz sha256=aaaa1111
      - cnos.eng@3.37.0 url=https://example.com/cnos.eng-3.37.0.tar.gz sha256=bbbb2222 |}]

(* === P2: parse_package_index on empty packages === *)

let%expect_test "P2 parse_package_index empty packages" =
  let payload =
    {|{ "schema": "cn.package-index.v1", "packages": {} }|}
  in
  let json = match Cn_json.parse payload with
    | Ok j -> j | Error _ -> failwith "json" in
  let idx = Cn_package.parse_package_index json in
  Printf.printf "schema=%s\n" idx.index_schema;
  Printf.printf "entry_count=%d\n" (List.length idx.index_entries);
  [%expect {|
    schema=cn.package-index.v1
    entry_count=0 |}]

(* === P3: parse_package_index ignores malformed version entries === *)

let%expect_test "P3 parse_package_index skips malformed entries" =
  let payload =
    {|{
      "schema": "cn.package-index.v1",
      "packages": {
        "good.pkg": {
          "1.0.0": { "url": "u", "sha256": "s" }
        },
        "bad.pkg": {
          "1.0.0": { "url": "u" }
        },
        "also.bad": "not an object"
      }
    }|}
  in
  let json = match Cn_json.parse payload with
    | Ok j -> j | Error _ -> failwith "json" in
  let idx = Cn_package.parse_package_index json in
  Printf.printf "entry_count=%d\n" (List.length idx.index_entries);
  let names = idx.index_entries
    |> List.map (fun ((n, _), _) -> n)
    |> List.sort compare in
  Printf.printf "names=%s\n" (String.concat "," names);
  [%expect {|
    entry_count=1
    names=good.pkg |}]

(* === L1: lookup_index hit === *)

let%expect_test "L1 lookup_index hit" =
  let idx : Cn_package.package_index = {
    index_schema = "cn.package-index.v1";
    index_entries = [
      (("cnos.core", "3.37.0"), { ie_url = "u1"; ie_sha256 = "h1" });
      (("cnos.eng",  "3.37.0"), { ie_url = "u2"; ie_sha256 = "h2" });
    ];
  } in
  (match Cn_package.lookup_index idx ~name:"cnos.core" ~version:"3.37.0" with
   | None -> print_endline "miss"
   | Some (e : Cn_package.index_entry) ->
       Printf.printf "url=%s sha256=%s\n" e.ie_url e.ie_sha256);
  [%expect {| url=u1 sha256=h1 |}]

(* === L2: lookup_index miss === *)

let%expect_test "L2 lookup_index miss returns None" =
  let idx : Cn_package.package_index = {
    index_schema = "cn.package-index.v1";
    index_entries = [
      (("cnos.core", "3.37.0"), { ie_url = "u"; ie_sha256 = "h" });
    ];
  } in
  (match Cn_package.lookup_index idx ~name:"cnos.eng" ~version:"3.37.0" with
   | None -> print_endline "miss"
   | Some _ -> print_endline "unexpected hit");
  (match Cn_package.lookup_index idx ~name:"cnos.core" ~version:"9.9.9" with
   | None -> print_endline "miss"
   | Some _ -> print_endline "unexpected hit");
  [%expect {|
    miss
    miss |}]

(* === F1: is_first_party positive cases === *)

let%expect_test "F1 is_first_party cnos.* names" =
  List.iter (fun n ->
    Printf.printf "%s -> %b\n" n (Cn_package.is_first_party n))
    ["cnos.core"; "cnos.eng"; "cnos.pm"; "cnos.net.http"];
  [%expect {|
    cnos.core -> true
    cnos.eng -> true
    cnos.pm -> true
    cnos.net.http -> true |}]

(* === F2: is_first_party negative cases === *)

let%expect_test "F2 is_first_party non-cnos and short names" =
  List.iter (fun n ->
    Printf.printf "%s -> %b\n" n (Cn_package.is_first_party n))
    [""; "c"; "cnos"; "cnos-core"; "other.pkg"; "example.com"];
  [%expect {|
     -> false
    c -> false
    cnos -> false
    cnos-core -> false
    other.pkg -> false
    example.com -> false |}]
