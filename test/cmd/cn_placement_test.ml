(** cn_placement_test: ppx_expect tests for hub placement manifest parsing (#156)

    Tests parse_manifest (pure JSON parsing), mode resolution,
    and backward-compatible standalone fallback. *)

(* === parse_manifest: attached mode === *)

let%expect_test "parse_manifest: valid attached with nested_clone" =
  let json = {|{
    "schema": "cn.hub_placement.v1",
    "mode": "attached",
    "hub_root": ".cn/hub",
    "workspace_root": ".",
    "backend": {
      "kind": "nested_clone",
      "remote": "git@github.com:me/agent-home.git"
    }
  }|} in
  (match Cn_placement.parse_manifest json with
   | Some p ->
       Printf.printf "mode=%s hub_root=%s workspace_root=%s\n"
         (Cn_placement.mode_to_string p.mode) p.hub_root p.workspace_root;
       (match p.backend with
        | Some b -> Printf.printf "backend=%s remote=%s\n"
            (Cn_placement.backend_kind_to_string b.kind) b.remote
        | None -> print_endline "backend=none")
   | None -> print_endline "PARSE_FAILED");
  [%expect {|
    mode=attached hub_root=.cn/hub workspace_root=.
    backend=nested_clone remote=git@github.com:me/agent-home.git |}]

let%expect_test "parse_manifest: valid attached with submodule" =
  let json = {|{
    "schema": "cn.hub_placement.v1",
    "mode": "attached",
    "hub_root": ".cn/hub",
    "workspace_root": ".",
    "backend": {
      "kind": "submodule",
      "remote": "https://github.com/me/agent-home.git"
    }
  }|} in
  (match Cn_placement.parse_manifest json with
   | Some p ->
       Printf.printf "mode=%s\n" (Cn_placement.mode_to_string p.mode);
       (match p.backend with
        | Some b -> Printf.printf "backend=%s\n"
            (Cn_placement.backend_kind_to_string b.kind)
        | None -> print_endline "backend=none")
   | None -> print_endline "PARSE_FAILED");
  [%expect {|
    mode=attached
    backend=submodule |}]

(* === parse_manifest: standalone mode === *)

let%expect_test "parse_manifest: valid standalone" =
  let json = {|{
    "schema": "cn.hub_placement.v1",
    "mode": "standalone"
  }|} in
  (match Cn_placement.parse_manifest json with
   | Some p ->
       Printf.printf "mode=%s hub_root=%s workspace_root=%s\n"
         (Cn_placement.mode_to_string p.mode) p.hub_root p.workspace_root;
       Printf.printf "is_attached=%b\n" (Cn_placement.is_attached p)
   | None -> print_endline "PARSE_FAILED");
  [%expect {|
    mode=standalone hub_root=. workspace_root=.
    is_attached=false |}]

(* === parse_manifest: error cases === *)

let%expect_test "parse_manifest: wrong schema version" =
  let json = {|{"schema": "cn.hub_placement.v2", "mode": "standalone"}|} in
  (match Cn_placement.parse_manifest json with
   | Some _ -> print_endline "PARSED"
   | None -> print_endline "NONE");
  [%expect {| NONE |}]

let%expect_test "parse_manifest: missing schema" =
  let json = {|{"mode": "standalone"}|} in
  (match Cn_placement.parse_manifest json with
   | Some _ -> print_endline "PARSED"
   | None -> print_endline "NONE");
  [%expect {| NONE |}]

let%expect_test "parse_manifest: attached missing hub_root" =
  let json = {|{
    "schema": "cn.hub_placement.v1",
    "mode": "attached",
    "workspace_root": "."
  }|} in
  (match Cn_placement.parse_manifest json with
   | Some _ -> print_endline "PARSED"
   | None -> print_endline "NONE");
  [%expect {| NONE |}]

let%expect_test "parse_manifest: attached missing workspace_root" =
  let json = {|{
    "schema": "cn.hub_placement.v1",
    "mode": "attached",
    "hub_root": ".cn/hub"
  }|} in
  (match Cn_placement.parse_manifest json with
   | Some _ -> print_endline "PARSED"
   | None -> print_endline "NONE");
  [%expect {| NONE |}]

let%expect_test "parse_manifest: invalid JSON" =
  (match Cn_placement.parse_manifest "not json at all" with
   | Some _ -> print_endline "PARSED"
   | None -> print_endline "NONE");
  [%expect {| NONE |}]

let%expect_test "parse_manifest: empty string" =
  (match Cn_placement.parse_manifest "" with
   | Some _ -> print_endline "PARSED"
   | None -> print_endline "NONE");
  [%expect {| NONE |}]

(* === standalone helper === *)

let%expect_test "standalone: creates placement with equal roots" =
  let p = Cn_placement.standalone "/home/user/hub" in
  Printf.printf "mode=%s hub_root=%s workspace_root=%s is_attached=%b\n"
    (Cn_placement.mode_to_string p.mode) p.hub_root p.workspace_root
    (Cn_placement.is_attached p);
  [%expect {| mode=standalone hub_root=/home/user/hub workspace_root=/home/user/hub is_attached=false |}]

(* === attached mode with no backend === *)

let%expect_test "parse_manifest: attached without backend" =
  let json = {|{
    "schema": "cn.hub_placement.v1",
    "mode": "attached",
    "hub_root": ".cn/hub",
    "workspace_root": "."
  }|} in
  (match Cn_placement.parse_manifest json with
   | Some p ->
       Printf.printf "mode=%s backend=%s\n"
         (Cn_placement.mode_to_string p.mode)
         (match p.backend with Some _ -> "present" | None -> "none")
   | None -> print_endline "PARSE_FAILED");
  [%expect {| mode=attached backend=none |}]
