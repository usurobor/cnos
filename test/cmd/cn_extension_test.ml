(** cn_extension_test: ppx_expect tests for extension manifest parsing,
    registry building, discovery, and dispatch integration.

    Tests the pure parsing core and registry logic.
    Discovery tests use temp directories. *)

let mk_temp_dir prefix =
  let base = Filename.get_temp_dir_name () in
  let rec attempt k =
    if k = 0 then failwith "mk_temp_dir: exhausted attempts";
    let dir =
      Filename.concat base
        (Printf.sprintf "%s-%d-%06d" prefix (Unix.getpid ()) (Random.int 1_000_000))
    in
    try Unix.mkdir dir 0o700; dir
    with Unix.Unix_error (Unix.EEXIST, _, _) -> attempt (k - 1)
  in
  Random.self_init ();
  attempt 50

(* === Manifest parsing === *)

let show_manifest_result = function
  | Ok (m : Cn_extension.extension_manifest) ->
    Printf.printf "ok name=%s version=%s ops=%d backend=%s\n"
      m.name m.version (List.length m.ops) m.backend.backend_kind
  | Error e ->
    Printf.printf "error: %s\n" e

let%expect_test "parse valid manifest" =
  let json = {|{
    "schema": "cn.extension.v1",
    "name": "cnos.net.http",
    "version": "1.0.0",
    "interface": "cn.ext.v1",
    "kind": "capability-provider",
    "backend": { "kind": "subprocess", "command": ["cnos-ext-http"] },
    "ops": [
      { "kind": "http_get", "class": "observe" },
      { "kind": "dns_resolve", "class": "observe" }
    ],
    "permissions": { "network": true },
    "engines": { "cnos": ">=3.12.0 <4.0.0" }
  }|} in
  show_manifest_result (Cn_extension.parse_manifest_string json);
  [%expect {| ok name=cnos.net.http version=1.0.0 ops=2 backend=subprocess |}]

let%expect_test "parse manifest missing name" =
  let json = {|{
    "schema": "cn.extension.v1",
    "version": "1.0.0",
    "interface": "cn.ext.v1",
    "backend": { "kind": "subprocess", "command": [] },
    "ops": []
  }|} in
  show_manifest_result (Cn_extension.parse_manifest_string json);
  [%expect {| error: missing required fields (schema, name, version, interface) |}]

let%expect_test "parse manifest missing ops" =
  let json = {|{
    "schema": "cn.extension.v1",
    "name": "test.ext",
    "version": "1.0.0",
    "interface": "cn.ext.v1",
    "backend": { "kind": "subprocess", "command": [] }
  }|} in
  show_manifest_result (Cn_extension.parse_manifest_string json);
  [%expect {| error: missing required field 'ops' |}]

let%expect_test "parse manifest invalid op class" =
  let json = {|{
    "schema": "cn.extension.v1",
    "name": "test.ext",
    "version": "1.0.0",
    "interface": "cn.ext.v1",
    "backend": { "kind": "subprocess", "command": [] },
    "ops": [{ "kind": "foo", "class": "invalid" }],
    "permissions": {},
    "engines": {}
  }|} in
  show_manifest_result (Cn_extension.parse_manifest_string json);
  [%expect {| error: invalid op class: invalid (must be observe or effect) |}]

let%expect_test "parse manifest with effect ops" =
  let json = {|{
    "schema": "cn.extension.v1",
    "name": "test.write",
    "version": "1.0.0",
    "interface": "cn.ext.v1",
    "backend": { "kind": "subprocess", "command": ["test-ext"] },
    "ops": [
      { "kind": "custom_write", "class": "effect" },
      { "kind": "custom_read", "class": "observe" }
    ],
    "permissions": {},
    "engines": {}
  }|} in
  show_manifest_result (Cn_extension.parse_manifest_string json);
  [%expect {| ok name=test.write version=1.0.0 ops=2 backend=subprocess |}]

let%expect_test "parse invalid JSON" =
  (match Cn_extension.parse_manifest_string "not json" with
   | Error msg ->
     (* Check prefix only — exact Cn_json.parse error wording varies by env *)
     let prefix = "JSON parse error:" in
     if String.length msg >= String.length prefix
        && String.sub msg 0 (String.length prefix) = prefix
     then print_endline "error: JSON parse error (details vary)"
     else Printf.printf "error: %s\n" msg
   | Ok _ -> print_endline "unexpected ok");
  [%expect {| error: JSON parse error (details vary) |}]

(* === Version compatibility === *)

let%expect_test "version constraint: compatible" =
  Printf.printf "%b\n"
    (Cn_extension.check_version_constraint
       ~runtime_version:"3.16.2" ">=3.12.0 <4.0.0");
  [%expect {| true |}]

let%expect_test "version constraint: too old" =
  Printf.printf "%b\n"
    (Cn_extension.check_version_constraint
       ~runtime_version:"3.11.0" ">=3.12.0 <4.0.0");
  [%expect {| false |}]

let%expect_test "version constraint: too new" =
  Printf.printf "%b\n"
    (Cn_extension.check_version_constraint
       ~runtime_version:"4.0.0" ">=3.12.0 <4.0.0");
  [%expect {| false |}]

let%expect_test "version constraint: exact boundary" =
  Printf.printf "%b\n"
    (Cn_extension.check_version_constraint
       ~runtime_version:"3.12.0" ">=3.12.0 <4.0.0");
  [%expect {| true |}]

(* === Op conflict detection === *)

let make_entry name ops_list state =
  let ops = List.map (fun (k, c) ->
    { Cn_extension.op_kind = k; op_class = c;
      request_schema = None; response_format = None }
  ) ops_list in
  { Cn_extension.
    manifest = {
      schema = "cn.extension.v1"; name; version = "1.0.0";
      interface = "cn.ext.v1"; ext_kind = "capability-provider";
      backend = { backend_kind = "subprocess"; command = [] };
      ops; permissions = []; engines = [];
    };
    package_name = name; package_path = "/tmp/" ^ name;
    extension_path = "/tmp/" ^ name ^ "/extensions/" ^ name;
    state;
  }

let%expect_test "op conflict: no conflicts" =
  let entries = [
    make_entry "ext.a" [("op_a", "observe")] Cn_extension.Compatible;
    make_entry "ext.b" [("op_b", "observe")] Cn_extension.Compatible;
  ] in
  let result = Cn_extension.check_op_conflicts entries in
  List.iter (fun e ->
    Printf.printf "%s: %s\n" e.Cn_extension.manifest.name
      (Cn_extension.string_of_lifecycle_state e.state)
  ) result;
  [%expect {|
    ext.a: compatible
    ext.b: compatible
  |}]

let%expect_test "op conflict: duplicate op kind rejected" =
  let entries = [
    make_entry "ext.a" [("shared_op", "observe")] Cn_extension.Compatible;
    make_entry "ext.b" [("shared_op", "observe")] Cn_extension.Compatible;
  ] in
  let result = Cn_extension.check_op_conflicts entries in
  List.iter (fun e ->
    Printf.printf "%s: %s\n" e.Cn_extension.manifest.name
      (Cn_extension.string_of_lifecycle_state e.state)
  ) result;
  [%expect {|
    ext.a: compatible
    ext.b: rejected: op kind 'shared_op' already provided by ext.a
  |}]

let%expect_test "op conflict: already rejected entries skipped" =
  let entries = [
    make_entry "ext.a" [("op_a", "observe")] (Cn_extension.Rejected "bad");
    make_entry "ext.b" [("op_a", "observe")] Cn_extension.Compatible;
  ] in
  let result = Cn_extension.check_op_conflicts entries in
  List.iter (fun e ->
    Printf.printf "%s: %s\n" e.Cn_extension.manifest.name
      (Cn_extension.string_of_lifecycle_state e.state)
  ) result;
  [%expect {|
    ext.a: rejected: bad
    ext.b: compatible
  |}]

(* === Enablement === *)

let%expect_test "enablement: compatible becomes enabled" =
  let entries = [
    make_entry "ext.a" [("op_a", "observe")] Cn_extension.Compatible;
  ] in
  let result = Cn_extension.apply_enablement entries in
  List.iter (fun e ->
    Printf.printf "%s: %s\n" e.Cn_extension.manifest.name
      (Cn_extension.string_of_lifecycle_state e.state)
  ) result;
  [%expect {| ext.a: enabled |}]

let%expect_test "enablement: disabled by config" =
  let entries = [
    make_entry "ext.a" [("op_a", "observe")] Cn_extension.Compatible;
  ] in
  let result = Cn_extension.apply_enablement
    ~disabled_extensions:["ext.a"] entries in
  List.iter (fun e ->
    Printf.printf "%s: %s\n" e.Cn_extension.manifest.name
      (Cn_extension.string_of_lifecycle_state e.state)
  ) result;
  [%expect {| ext.a: disabled |}]

(* === Registry building and op lookup === *)

let%expect_test "registry: lookup enabled op" =
  let entries = [
    make_entry "ext.a" [("op_a", "observe"); ("op_b", "effect")]
      Cn_extension.Compatible;
  ] in
  let enabled = Cn_extension.apply_enablement entries in
  let reg = { Cn_extension.extensions = enabled;
              op_index = Hashtbl.create 8 } in
  enabled |> List.iter (fun entry ->
    match entry.Cn_extension.state with
    | Cn_extension.Enabled ->
      entry.manifest.ops |> List.iter (fun op ->
        Hashtbl.replace reg.op_index op.Cn_extension.op_kind (entry, op))
    | _ -> ());
  (match Cn_extension.lookup_op reg "op_a" with
   | Some (entry, op) ->
     Printf.printf "found: %s %s\n" entry.manifest.name op.op_class
   | None -> Printf.printf "not found\n");
  (match Cn_extension.lookup_op reg "unknown_op" with
   | Some _ -> Printf.printf "found (wrong!)\n"
   | None -> Printf.printf "not found\n");
  [%expect {|
    found: ext.a observe
    not found
  |}]

let%expect_test "empty registry: lookup returns None" =
  let reg = Cn_extension.empty_registry () in
  (match Cn_extension.lookup_op reg "anything" with
   | Some _ -> Printf.printf "found (wrong!)\n"
   | None -> Printf.printf "not found\n");
  [%expect {| not found |}]

(* === Extension op kind in cn_shell === *)

let%expect_test "shell: extension op parsed via ext_lookup" =
  let ext_lookup = function
    | "http_get" -> Some ("http_get", "observe")
    | "custom_write" -> Some ("custom_write", "effect")
    | _ -> None
  in
  let ops, receipts = Cn_shell.parse_ops_manifest ~ext_lookup
    {|[{"kind":"http_get","url":"https://example.com"},{"kind":"custom_write","op_id":"w-01","data":"test"}]|} in
  Printf.printf "ops=%d receipts=%d\n" (List.length ops) (List.length receipts);
  List.iter (fun (op : Cn_shell.typed_op) ->
    Printf.printf "  %s effect=%b\n"
      (Cn_shell.string_of_op_kind op.kind)
      (Cn_shell.is_effect op.kind)
  ) ops;
  [%expect {|
    ops=2 receipts=0
      http_get effect=false
      custom_write effect=true
  |}]

let%expect_test "shell: unknown op kind without ext_lookup is denied" =
  let ops, receipts = Cn_shell.parse_ops_manifest
    {|[{"kind":"http_get"}]|} in
  Printf.printf "ops=%d receipts=%d\n" (List.length ops) (List.length receipts);
  List.iter (fun r ->
    Printf.printf "  %s %s\n" r.Cn_shell.kind r.Cn_shell.reason
  ) receipts;
  [%expect {|
    ops=0 receipts=1
      http_get unknown_op_kind
  |}]

let%expect_test "shell: extension observe op auto-assigns id" =
  let ext_lookup = function
    | "http_get" -> Some ("http_get", "observe")
    | _ -> None
  in
  let ops, _ = Cn_shell.parse_ops_manifest ~ext_lookup
    {|[{"kind":"http_get","url":"https://example.com"}]|} in
  List.iter (fun (op : Cn_shell.typed_op) ->
    Printf.printf "%s id=%s\n"
      (Cn_shell.string_of_op_kind op.kind)
      (match op.op_id with Some id -> id | None -> "none")
  ) ops;
  [%expect {| http_get id=obs-01 |}]

let%expect_test "shell: extension effect op requires op_id" =
  let ext_lookup = function
    | "custom_write" -> Some ("custom_write", "effect")
    | _ -> None
  in
  let _ops, receipts = Cn_shell.parse_ops_manifest ~ext_lookup
    {|[{"kind":"custom_write","data":"test"}]|} in
  List.iter (fun r ->
    Printf.printf "%s %s %s\n" r.Cn_shell.kind
      (Cn_shell.string_of_receipt_status r.status) r.reason
  ) receipts;
  [%expect {| custom_write denied missing_op_id |}]

(* === Extension JSON serialization === *)

let%expect_test "extension_to_json" =
  let entry = make_entry "cnos.net.http"
    [("http_get", "observe"); ("dns_resolve", "observe")]
    Cn_extension.Enabled in
  let json = Cn_extension.extension_to_json entry in
  let name = Cn_json.get_string "name" json in
  let state = Cn_json.get_string "state" json in
  Printf.printf "name=%s state=%s\n"
    (match name with Some s -> s | None -> "?")
    (match state with Some s -> s | None -> "?");
  [%expect {| name=cnos.net.http state=enabled |}]

(* === Host protocol JSON === *)

let%expect_test "host: execute request serialization" =
  let req = Cn_ext_host.Execute {
    op_kind = "http_get";
    arguments = [("url", Cn_json.String "https://example.com")];
    limits = [("timeout_sec", Cn_json.Int 30)];
    permissions = [("allowed_domains", Cn_json.Array [Cn_json.String "example.com"])];
  } in
  let json = Cn_ext_host.request_to_json req in
  let method_ = Cn_json.get_string "method" json in
  Printf.printf "method=%s\n"
    (match method_ with Some s -> s | None -> "?");
  let op = Cn_json.get "op" json in
  (match op with
   | Some obj ->
     let kind = Cn_json.get_string "kind" obj in
     Printf.printf "op.kind=%s\n"
       (match kind with Some s -> s | None -> "?")
   | None -> Printf.printf "no op\n");
  [%expect {|
    method=execute
    op.kind=http_get
  |}]

let%expect_test "host: describe request serialization" =
  let json = Cn_ext_host.request_to_json Cn_ext_host.Describe in
  let method_ = Cn_json.get_string "method" json in
  Printf.printf "method=%s\n"
    (match method_ with Some s -> s | None -> "?");
  [%expect {| method=describe |}]

let%expect_test "host: parse ok response" =
  let json = Cn_json.Object [
    ("status", Cn_json.String "ok");
    ("data", Cn_json.Object [("content", Cn_json.String "hello")]);
  ] in
  (match Cn_ext_host.parse_response json with
   | Ok resp -> Printf.printf "status=%s has_data=%b\n"
       resp.status (resp.data <> None)
   | Error e -> Printf.printf "error: %s\n" e);
  [%expect {| status=ok has_data=true |}]

let%expect_test "host: parse error response" =
  let json = Cn_json.Object [
    ("status", Cn_json.String "error");
    ("error", Cn_json.String "domain_not_allowed");
  ] in
  (match Cn_ext_host.parse_response json with
   | Ok resp -> Printf.printf "status=%s error=%s\n"
       resp.status (match resp.error with Some e -> e | None -> "none")
   | Error e -> Printf.printf "parse error: %s\n" e);
  [%expect {| status=error error=domain_not_allowed |}]

(* === Discovery integration (filesystem) === *)

let%expect_test "discover: empty vendor dir" =
  let tmp = mk_temp_dir "cn-ext-test" in
  let vendor = tmp ^ "/.cn/vendor/packages" in
  Cn_ffi.Fs.ensure_dir vendor;
  let entries = Cn_extension.discover ~hub_path:tmp in
  Printf.printf "found=%d\n" (List.length entries);
  [%expect {| found=0 |}]

let%expect_test "discover: finds extension manifest" =
  let tmp = mk_temp_dir "cn-ext-test" in
  let ext_dir = tmp ^ "/.cn/vendor/packages/cnos.net.http@1.0.0/extensions/cnos.net.http" in
  Cn_ffi.Fs.ensure_dir ext_dir;
  Cn_ffi.Fs.write (ext_dir ^ "/cn.extension.json") {|{
    "schema": "cn.extension.v1",
    "name": "cnos.net.http",
    "version": "1.0.0",
    "interface": "cn.ext.v1",
    "backend": { "kind": "subprocess", "command": ["cnos-ext-http"] },
    "ops": [{ "kind": "http_get", "class": "observe" }],
    "permissions": {},
    "engines": { "cnos": ">=3.12.0 <4.0.0" }
  }|};
  let entries = Cn_extension.discover ~hub_path:tmp in
  Printf.printf "found=%d\n" (List.length entries);
  List.iter (fun e ->
    Printf.printf "  %s pkg=%s state=%s ops=%d\n"
      e.Cn_extension.manifest.name
      e.package_name
      (Cn_extension.string_of_lifecycle_state e.state)
      (List.length e.manifest.ops)
  ) entries;
  [%expect {|
    found=1
      cnos.net.http pkg=cnos.net.http state=discovered ops=1
  |}]

let%expect_test "build_registry: full lifecycle" =
  let tmp = mk_temp_dir "cn-ext-test" in
  let ext_dir = tmp ^ "/.cn/vendor/packages/cnos.net.http@1.0.0/extensions/cnos.net.http" in
  Cn_ffi.Fs.ensure_dir ext_dir;
  Cn_ffi.Fs.write (ext_dir ^ "/cn.extension.json") {|{
    "schema": "cn.extension.v1",
    "name": "cnos.net.http",
    "version": "1.0.0",
    "interface": "cn.ext.v1",
    "backend": { "kind": "subprocess", "command": ["cnos-ext-http"] },
    "ops": [
      { "kind": "http_get", "class": "observe" },
      { "kind": "dns_resolve", "class": "observe" }
    ],
    "permissions": { "network": true },
    "engines": { "cnos": ">=3.12.0 <4.0.0" }
  }|};
  let reg = Cn_extension.build_registry ~hub_path:tmp
    ~runtime_version:"3.17.0" () in
  Printf.printf "extensions=%d\n" (List.length reg.extensions);
  reg.extensions |> List.iter (fun e ->
    Printf.printf "  %s state=%s\n"
      e.Cn_extension.manifest.name
      (Cn_extension.string_of_lifecycle_state e.state));
  (* Verify op lookup works *)
  (match Cn_extension.lookup_op reg "http_get" with
   | Some (_, op) -> Printf.printf "http_get: %s\n" op.op_class
   | None -> Printf.printf "http_get: not found\n");
  (match Cn_extension.lookup_op reg "dns_resolve" with
   | Some (_, op) -> Printf.printf "dns_resolve: %s\n" op.op_class
   | None -> Printf.printf "dns_resolve: not found\n");
  (match Cn_extension.lookup_op reg "fs_read" with
   | Some _ -> Printf.printf "fs_read: found (wrong!)\n"
   | None -> Printf.printf "fs_read: not found (correct — built-in)\n");
  [%expect {|
    extensions=1
      cnos.net.http state=enabled
    http_get: observe
    dns_resolve: observe
    fs_read: not found (correct — built-in)
  |}]

let%expect_test "build_registry: incompatible engine rejected" =
  let tmp = mk_temp_dir "cn-ext-test" in
  let ext_dir = tmp ^ "/.cn/vendor/packages/old.ext@1.0.0/extensions/old.ext" in
  Cn_ffi.Fs.ensure_dir ext_dir;
  Cn_ffi.Fs.write (ext_dir ^ "/cn.extension.json") {|{
    "schema": "cn.extension.v1",
    "name": "old.ext",
    "version": "1.0.0",
    "interface": "cn.ext.v1",
    "backend": { "kind": "subprocess", "command": [] },
    "ops": [{ "kind": "old_op", "class": "observe" }],
    "permissions": {},
    "engines": { "cnos": ">=4.0.0 <5.0.0" }
  }|};
  let reg = Cn_extension.build_registry ~hub_path:tmp
    ~runtime_version:"3.17.0" () in
  reg.extensions |> List.iter (fun e ->
    Printf.printf "%s: %s\n" e.Cn_extension.manifest.name
      (Cn_extension.string_of_lifecycle_state e.state));
  (match Cn_extension.lookup_op reg "old_op" with
   | Some _ -> Printf.printf "old_op: found (wrong!)\n"
   | None -> Printf.printf "old_op: not found (correct — rejected)\n");
  [%expect {|
    old.ext: rejected: engine incompatible: requires cnos >=4.0.0 <5.0.0, have 3.17.0
    old_op: not found (correct — rejected)
  |}]

let%expect_test "build_registry: disabled extension" =
  let tmp = mk_temp_dir "cn-ext-test" in
  let ext_dir = tmp ^ "/.cn/vendor/packages/cnos.net.http@1.0.0/extensions/cnos.net.http" in
  Cn_ffi.Fs.ensure_dir ext_dir;
  Cn_ffi.Fs.write (ext_dir ^ "/cn.extension.json") {|{
    "schema": "cn.extension.v1",
    "name": "cnos.net.http",
    "version": "1.0.0",
    "interface": "cn.ext.v1",
    "backend": { "kind": "subprocess", "command": ["cnos-ext-http"] },
    "ops": [{ "kind": "http_get", "class": "observe" }],
    "permissions": {},
    "engines": {}
  }|};
  let reg = Cn_extension.build_registry ~hub_path:tmp
    ~runtime_version:"3.17.0"
    ~disabled_extensions:["cnos.net.http"] () in
  reg.extensions |> List.iter (fun e ->
    Printf.printf "%s: %s\n" e.Cn_extension.manifest.name
      (Cn_extension.string_of_lifecycle_state e.state));
  (match Cn_extension.lookup_op reg "http_get" with
   | Some _ -> Printf.printf "http_get: found (wrong — should be disabled)\n"
   | None -> Printf.printf "http_get: not found (correct — disabled)\n");
  [%expect {|
    cnos.net.http: disabled
    http_get: not found (correct — disabled)
  |}]

(* === Policy intersection === *)

(* Invariant: effective permissions = extension-declared ∩ runtime-allowed.
   Secrets are always stripped. Network passes through if declared. *)

let test_manifest ?(permissions = []) () : Cn_extension.extension_manifest =
  { schema = "cn.extension.v1"; name = "test.ext"; version = "1.0.0";
    interface = "cn.ext.v1"; ext_kind = "capability-provider";
    backend = { backend_kind = "subprocess"; command = ["test-host"] };
    ops = []; permissions;
    engines = [] }

(* exec_enabled=true to test permission intersection; false tested below *)
let exec_config = { Cn_shell.default_shell_config with exec_enabled = true }

let%expect_test "effective_permissions: network passes through when declared" =
  let manifest = test_manifest ~permissions:[
    "network", Cn_json.Bool true;
    "default_read_only", Cn_json.Bool true;
  ] () in
  let eff = Cn_extension.effective_permissions ~manifest ~config:exec_config in
  List.iter (fun (k, _) -> Printf.printf "%s\n" k) eff;
  [%expect {|
    network
    default_read_only
  |}]

let%expect_test "effective_permissions: no network when not declared" =
  let manifest = test_manifest ~permissions:[
    "default_read_only", Cn_json.Bool true;
  ] () in
  let eff = Cn_extension.effective_permissions ~manifest ~config:exec_config in
  List.iter (fun (k, _) -> Printf.printf "%s\n" k) eff;
  [%expect {| default_read_only |}]

(* Invariant: secrets are never passed to the host — always stripped to empty *)
let%expect_test "effective_permissions: secrets always stripped" =
  let manifest = test_manifest ~permissions:[
    "allow_secrets", Cn_json.Array [Cn_json.String "API_KEY"];
  ] () in
  let eff = Cn_extension.effective_permissions ~manifest ~config:exec_config in
  List.iter (fun (k, v) ->
    Printf.printf "%s=%s\n" k (Cn_json.to_string v)) eff;
  [%expect {| allow_secrets=[] |}]

(* Invariant: exec_enabled=false gates ALL permissions — nothing passes through *)
let%expect_test "effective_permissions: exec_disabled returns empty" =
  let manifest = test_manifest ~permissions:[
    "network", Cn_json.Bool true;
    "default_read_only", Cn_json.Bool true;
    "allow_secrets", Cn_json.Array [Cn_json.String "KEY"];
  ] () in
  let config = Cn_shell.default_shell_config in (* exec_enabled=false *)
  let eff = Cn_extension.effective_permissions ~manifest ~config in
  Printf.printf "permissions count: %d\n" (List.length eff);
  [%expect {| permissions count: 0 |}]

let%expect_test "execution_limits: derives from shell_config" =
  let config = { Cn_shell.default_shell_config with
    max_artifact_bytes_per_op = 8192 } in
  let limits = Cn_extension.execution_limits ~config in
  List.iter (fun (k, v) ->
    Printf.printf "%s=%s\n" k (Cn_json.to_string v)) limits;
  [%expect {| max_artifact_bytes=8192 |}]

(* === Host binary protocol (cnos-ext-http stub) === *)

(* Resolve host binary path. Works from repo root (local dev),
   dune build sandbox (_build/default/test/cmd/), and dune inline_tests.
   The dune (deps) stanza ensures the file is available. *)
let find_host_binary () =
  let rel = "src/agent/extensions/cnos.net.http/host/cnos-ext-http" in
  let candidates = [
    (* dune inline_tests: deps path relative to test/cmd/ *)
    "../../" ^ rel;
    (* repo root (cwd = repo root) *)
    Sys.getcwd () ^ "/" ^ rel;
    (* walk up from cwd to find repo root *)
    "../../../" ^ rel;
    "../../../../" ^ rel;
  ] in
  List.find_opt Sys.file_exists candidates

(* Invariant: host responds to describe with extension metadata *)
let%expect_test "host stub: describe returns extension info" =
  (match find_host_binary () with
   | None -> Printf.printf "host not found (skipping)\n"
   | Some host_path ->
     let request = Cn_ext_host.request_to_json Cn_ext_host.Describe in
     let input = Cn_json.to_string request ^ "\n" in
     let code, output =
       Cn_ffi.Process.exec_args ~prog:host_path ~args:[]
         ~stdin_data:input () in
     Printf.printf "exit=%d\n" code;
     (match Cn_json.parse (String.trim output) with
      | Ok json ->
        (match Cn_json.get_string "status" json with
         | Some s -> Printf.printf "status=%s\n" s
         | None -> Printf.printf "no status\n");
        (match Cn_json.get "data" json with
         | Some data ->
           (match Cn_json.get_string "name" data with
            | Some n -> Printf.printf "name=%s\n" n
            | None -> Printf.printf "no name\n")
         | None -> Printf.printf "no data\n")
      | Error e -> Printf.printf "parse error: %s\n" e));
  [%expect {|
    exit=0
    status=ok
    name=cnos.net.http
  |}]

(* Invariant: host responds to health check *)
let%expect_test "host stub: health returns ok" =
  (match find_host_binary () with
   | None -> Printf.printf "host not found (skipping)\n"
   | Some host_path ->
     match Cn_ext_host.check_health ~command:[host_path] () with
     | Ok () -> Printf.printf "healthy\n"
     | Error msg -> Printf.printf "unhealthy: %s\n" msg);
  [%expect {| healthy |}]

(* Negative space: host rejects unknown op kinds *)
let%expect_test "host stub: unknown op kind rejected" =
  (match find_host_binary () with
   | None -> Printf.printf "host not found (skipping)\n"
   | Some host_path ->
     let result = Cn_ext_host.execute_extension_op
       ~command:[host_path] ~op_kind:"nonexistent_op"
       ~arguments:[] () in
     match result with
     | Ok _ -> Printf.printf "ok (wrong — should reject)\n"
     | Error msg -> Printf.printf "rejected: %s\n" msg);
  [%expect {| rejected: unknown op kind: nonexistent_op |}]

(* Negative space: http_get rejects missing URL *)
let%expect_test "host stub: http_get without url rejected" =
  (match find_host_binary () with
   | None -> Printf.printf "host not found (skipping)\n"
   | Some host_path ->
     let result = Cn_ext_host.execute_extension_op
       ~command:[host_path] ~op_kind:"http_get"
       ~arguments:[] () in
     match result with
     | Ok _ -> Printf.printf "ok (wrong — should reject)\n"
     | Error msg -> Printf.printf "rejected: %s\n" msg);
  [%expect {| rejected: missing required field: url |}]

(* Negative space: http_get rejects non-http URL schemes *)
let%expect_test "host stub: http_get rejects file:// scheme" =
  (match find_host_binary () with
   | None -> Printf.printf "host not found (skipping)\n"
   | Some host_path ->
     let result = Cn_ext_host.execute_extension_op
       ~command:[host_path] ~op_kind:"http_get"
       ~arguments:["url", Cn_json.String "file:///etc/passwd"] () in
     match result with
     | Ok _ -> Printf.printf "ok (wrong — should reject)\n"
     | Error msg -> Printf.printf "rejected: %s\n" msg);
  [%expect {| rejected: url must use http or https scheme |}]

(* === Command resolution === *)

let%expect_test "resolve_command: bare name resolved to extension host dir" =
  (* Create a real host binary so resolve_command can find it *)
  let tmp = mk_temp_dir "resolve-bare" in
  let ext_path = tmp ^ "/extensions/cnos.net.http" in
  let host_dir = ext_path ^ "/host" in
  Unix.mkdir (tmp ^ "/extensions") 0o700;
  Unix.mkdir ext_path 0o700;
  Unix.mkdir host_dir 0o700;
  let prog_path = host_dir ^ "/cnos-ext-http" in
  let oc = open_out prog_path in
  output_string oc "#!/bin/sh\n"; close_out oc;
  Unix.chmod prog_path 0o755;
  let entry = { Cn_extension.
    manifest = {
      schema = "cn.extension.v1"; name = "cnos.net.http"; version = "1.0.0";
      interface = "cn.ext.v1"; ext_kind = "capability-provider";
      backend = { backend_kind = "subprocess"; command = ["cnos-ext-http"] };
      ops = []; permissions = []; engines = [];
    };
    package_name = "cnos.core";
    package_path = tmp;
    extension_path = ext_path;
    state = Enabled;
  } in
  (match Cn_extension.resolve_command entry with
   | Ok cmd ->
     let has_suffix s suffix =
       let sl = String.length s and xl = String.length suffix in
       sl >= xl && String.sub s (sl - xl) xl = suffix in
     Printf.printf "ok suffix=%b\n"
       (has_suffix (List.hd cmd) "/extensions/cnos.net.http/host/cnos-ext-http")
   | Error e -> Printf.printf "error: %s\n" e);
  [%expect {| ok suffix=true |}]

let%expect_test "resolve_command: missing host binary returns error" =
  let entry = { Cn_extension.
    manifest = {
      schema = "cn.extension.v1"; name = "cnos.net.http"; version = "1.0.0";
      interface = "cn.ext.v1"; ext_kind = "capability-provider";
      backend = { backend_kind = "subprocess"; command = ["cnos-ext-http"] };
      ops = []; permissions = []; engines = [];
    };
    package_name = "cnos.core";
    package_path = "/nonexistent/pkg";
    extension_path = "/nonexistent/pkg/extensions/cnos.net.http";
    state = Enabled;
  } in
  (match Cn_extension.resolve_command entry with
   | Ok _ -> Printf.printf "ok (unexpected)\n"
   | Error e -> Printf.printf "error: %s\n" e);
  [%expect {| error: host binary not found: /nonexistent/pkg/extensions/cnos.net.http/host/cnos-ext-http |}]

let%expect_test "resolve_command: non-executable host binary returns error" =
  let tmp = mk_temp_dir "resolve-noexec" in
  let ext_path = tmp ^ "/extensions/test.ext" in
  let host_dir = ext_path ^ "/host" in
  Unix.mkdir (tmp ^ "/extensions") 0o700;
  Unix.mkdir ext_path 0o700;
  Unix.mkdir host_dir 0o700;
  let prog_path = host_dir ^ "/test-prog" in
  let oc = open_out prog_path in
  output_string oc "not executable"; close_out oc;
  Unix.chmod prog_path 0o644;  (* readable but not executable *)
  let entry = { Cn_extension.
    manifest = {
      schema = "cn.extension.v1"; name = "test.ext"; version = "1.0.0";
      interface = "cn.ext.v1"; ext_kind = "capability-provider";
      backend = { backend_kind = "subprocess"; command = ["test-prog"] };
      ops = []; permissions = []; engines = [];
    };
    package_name = "test.pkg";
    package_path = tmp;
    extension_path = ext_path;
    state = Enabled;
  } in
  (match Cn_extension.resolve_command entry with
   | Ok _ -> Printf.printf "ok (unexpected)\n"
   | Error e ->
     let has_sub s sub =
       let sl = String.length s and xl = String.length sub in
       let rec check i = i + xl <= sl &&
         (String.sub s i xl = sub || check (i + 1)) in
       check 0 in
     Printf.printf "error_contains_not_executable=%b\n"
       (has_sub e "not executable"));
  [%expect {| error_contains_not_executable=true |}]

let%expect_test "resolve_command: absolute path passed through" =
  (* /bin/sh exists and is executable on all POSIX systems *)
  let entry = { Cn_extension.
    manifest = {
      schema = "cn.extension.v1"; name = "test.ext"; version = "1.0.0";
      interface = "cn.ext.v1"; ext_kind = "capability-provider";
      backend = { backend_kind = "subprocess"; command = ["/bin/sh"; "-c"; "echo hi"] };
      ops = []; permissions = []; engines = [];
    };
    package_name = "test.pkg";
    package_path = "/tmp/test.pkg";
    extension_path = "/tmp/test.pkg/extensions/test.ext";
    state = Enabled;
  } in
  (match Cn_extension.resolve_command entry with
   | Ok cmd -> List.iter (Printf.printf "%s\n") cmd
   | Error e -> Printf.printf "error: %s\n" e);
  [%expect {|
    /bin/sh
    -c
    echo hi |}]

let%expect_test "resolve_command: empty command returns error" =
  let entry = { Cn_extension.
    manifest = {
      schema = "cn.extension.v1"; name = "test.ext"; version = "1.0.0";
      interface = "cn.ext.v1"; ext_kind = "capability-provider";
      backend = { backend_kind = "subprocess"; command = [] };
      ops = []; permissions = []; engines = [];
    };
    package_name = "test.pkg";
    package_path = "/tmp/test.pkg";
    extension_path = "/tmp/test.pkg/extensions/test.ext";
    state = Enabled;
  } in
  (match Cn_extension.resolve_command entry with
   | Ok _ -> Printf.printf "ok (unexpected)\n"
   | Error e -> Printf.printf "error: %s\n" e);
  [%expect {| error: extension declares empty command |}]

let%expect_test "resolve_command: path traversal rejected" =
  let entry = { Cn_extension.
    manifest = {
      schema = "cn.extension.v1"; name = "test.ext"; version = "1.0.0";
      interface = "cn.ext.v1"; ext_kind = "capability-provider";
      backend = { backend_kind = "subprocess"; command = ["../escape"] };
      ops = []; permissions = []; engines = [];
    };
    package_name = "test.pkg";
    package_path = "/tmp/test.pkg";
    extension_path = "/tmp/test.pkg/extensions/test.ext";
    state = Enabled;
  } in
  (match Cn_extension.resolve_command entry with
   | Ok _ -> Printf.printf "ok (unexpected)\n"
   | Error e -> Printf.printf "error: %s\n" e);
  [%expect {| error: command contains path separator: ../escape (only bare names allowed) |}]

let%expect_test "resolve_command: subdirectory traversal rejected" =
  let entry = { Cn_extension.
    manifest = {
      schema = "cn.extension.v1"; name = "test.ext"; version = "1.0.0";
      interface = "cn.ext.v1"; ext_kind = "capability-provider";
      backend = { backend_kind = "subprocess"; command = ["subdir/prog"] };
      ops = []; permissions = []; engines = [];
    };
    package_name = "test.pkg";
    package_path = "/tmp/test.pkg";
    extension_path = "/tmp/test.pkg/extensions/test.ext";
    state = Enabled;
  } in
  (match Cn_extension.resolve_command entry with
   | Ok _ -> Printf.printf "ok (unexpected)\n"
   | Error e -> Printf.printf "error: %s\n" e);
  [%expect {| error: command contains path separator: subdir/prog (only bare names allowed) |}]

(* === End-to-end dispatch: discovery → registry → resolve → host === *)

let%expect_test "e2e: discovered extension resolves command through installed path" =
  let hub = mk_temp_dir "ext-e2e" in
  let pkg_dir = hub ^ "/.cn/vendor/packages/cnos.core@3.17.0" in
  let ext_dir = pkg_dir ^ "/extensions/cnos.net.http" in
  Unix.mkdir (hub ^ "/.cn") 0o700;
  Unix.mkdir (hub ^ "/.cn/vendor") 0o700;
  Unix.mkdir (hub ^ "/.cn/vendor/packages") 0o700;
  Unix.mkdir pkg_dir 0o700;
  Unix.mkdir (pkg_dir ^ "/extensions") 0o700;
  Unix.mkdir ext_dir 0o700;
  let manifest = {|{
    "schema": "cn.extension.v1",
    "name": "cnos.net.http",
    "version": "1.0.0",
    "interface": "cn.ext.v1",
    "backend": { "kind": "subprocess", "command": ["cnos-ext-http"] },
    "ops": [{ "kind": "http_get", "class": "observe" }],
    "permissions": { "network": true },
    "engines": {}
  }|} in
  let oc = open_out (ext_dir ^ "/cn.extension.json") in
  output_string oc manifest; close_out oc;
  let reg = Cn_extension.build_registry ~hub_path:hub ~runtime_version:"3.17.0" () in
  let entries = Cn_extension.all_entries reg in
  (match entries with
   | [e] ->
     Printf.printf "name=%s state=%s\n" e.Cn_extension.manifest.name
       (Cn_extension.string_of_lifecycle_state e.state);
     (* Verify extension_path ends with the expected suffix *)
     let has_suffix s suffix =
       let sl = String.length s and xl = String.length suffix in
       sl >= xl && String.sub s (sl - xl) xl = suffix in
     Printf.printf "ext_path_suffix=%b\n"
       (has_suffix e.extension_path "/extensions/cnos.net.http");
     (* resolve_command returns Error because host binary doesn't exist in this
        minimal layout — but we can verify the path structure from the error *)
     (match Cn_extension.resolve_command e with
      | Ok _ -> Printf.printf "resolved=ok (unexpected — no binary installed)\n"
      | Error msg ->
        Printf.printf "resolved_error_has_correct_path=%b\n"
          (has_suffix msg "/extensions/cnos.net.http/host/cnos-ext-http"))
   | _ -> Printf.printf "unexpected entry count: %d\n" (List.length entries));
  [%expect {|
    name=cnos.net.http state=enabled
    ext_path_suffix=true
    resolved_error_has_correct_path=true |}]

let%expect_test "e2e: resolve_command + host health through installed layout" =
  (* Set up an installed layout with the real host binary *)
  (match find_host_binary () with
   | None -> Printf.printf "host not found (skipping)\n"
   | Some real_host_path ->
     let hub = mk_temp_dir "ext-e2e-host" in
     let pkg_dir = hub ^ "/.cn/vendor/packages/cnos.core@3.17.0" in
     let ext_dir = pkg_dir ^ "/extensions/cnos.net.http" in
     let host_dir = ext_dir ^ "/host" in
     Unix.mkdir (hub ^ "/.cn") 0o700;
     Unix.mkdir (hub ^ "/.cn/vendor") 0o700;
     Unix.mkdir (hub ^ "/.cn/vendor/packages") 0o700;
     Unix.mkdir pkg_dir 0o700;
     Unix.mkdir (pkg_dir ^ "/extensions") 0o700;
     Unix.mkdir ext_dir 0o700;
     Unix.mkdir host_dir 0o700;
     (* Copy real host binary into installed layout *)
     let content = let ic = open_in real_host_path in
       let n = in_channel_length ic in
       let s = Bytes.create n in
       really_input ic s 0 n; close_in ic; Bytes.to_string s in
     let dest = host_dir ^ "/cnos-ext-http" in
     let oc = open_out dest in
     output_string oc content; close_out oc;
     Unix.chmod dest 0o755;
     (* Write manifest *)
     let manifest = {|{
       "schema": "cn.extension.v1",
       "name": "cnos.net.http",
       "version": "1.0.0",
       "interface": "cn.ext.v1",
       "backend": { "kind": "subprocess", "command": ["cnos-ext-http"] },
       "ops": [{ "kind": "http_get", "class": "observe" }],
       "permissions": { "network": true },
       "engines": {}
     }|} in
     let oc = open_out (ext_dir ^ "/cn.extension.json") in
     output_string oc manifest; close_out oc;
     (* Build registry — simulates boot-time discovery *)
     let reg = Cn_extension.build_registry ~hub_path:hub ~runtime_version:"3.17.0" () in
     let entries = Cn_extension.all_entries reg in
     match entries with
     | [e] ->
       (* Resolve command through the installed path *)
       (match Cn_extension.resolve_command e with
        | Error reason -> Printf.printf "resolve error: %s\n" reason
        | Ok cmd ->
          (* Run health check through resolved command — proves e2e dispatch *)
          (match Cn_ext_host.check_health ~command:cmd () with
           | Ok () -> Printf.printf "health=ok\n"
           | Error msg -> Printf.printf "health=error: %s\n" msg);
          (* Run describe through resolved command *)
          (match cmd with
           | prog :: args ->
             let request = Cn_ext_host.request_to_json Cn_ext_host.Describe in
             let input = Cn_json.to_string request ^ "\n" in
             let code, output = Cn_ffi.Process.exec_args ~prog ~args
               ~stdin_data:input () in
             Printf.printf "describe_exit=%d\n" code;
             (match Cn_json.parse (String.trim output) with
              | Ok json ->
                (match Cn_json.get_string "status" json with
                 | Some s -> Printf.printf "describe_status=%s\n" s
                 | None -> Printf.printf "no status\n")
              | Error _ -> Printf.printf "parse error\n")
           | [] -> Printf.printf "empty command\n"))
     | _ -> Printf.printf "unexpected entry count: %d\n" (List.length entries));
  [%expect {|
    health=ok
    describe_exit=0
    describe_status=ok |}]

(* === E2E negative paths === *)

let%expect_test "e2e negative: missing host binary detected at resolution" =
  let hub = mk_temp_dir "ext-e2e-nohost" in
  let pkg_dir = hub ^ "/.cn/vendor/packages/cnos.core@3.17.0" in
  let ext_dir = pkg_dir ^ "/extensions/cnos.net.http" in
  Unix.mkdir (hub ^ "/.cn") 0o700;
  Unix.mkdir (hub ^ "/.cn/vendor") 0o700;
  Unix.mkdir (hub ^ "/.cn/vendor/packages") 0o700;
  Unix.mkdir pkg_dir 0o700;
  Unix.mkdir (pkg_dir ^ "/extensions") 0o700;
  Unix.mkdir ext_dir 0o700;
  (* No host/ directory — binary is missing *)
  let manifest = {|{
    "schema": "cn.extension.v1",
    "name": "cnos.net.http",
    "version": "1.0.0",
    "interface": "cn.ext.v1",
    "backend": { "kind": "subprocess", "command": ["cnos-ext-http"] },
    "ops": [{ "kind": "http_get", "class": "observe" }],
    "permissions": {},
    "engines": {}
  }|} in
  let oc = open_out (ext_dir ^ "/cn.extension.json") in
  output_string oc manifest; close_out oc;
  let reg = Cn_extension.build_registry ~hub_path:hub ~runtime_version:"3.17.0" () in
  let entries = Cn_extension.all_entries reg in
  (match entries with
   | [e] ->
     (match Cn_extension.resolve_command e with
      | Ok _ -> Printf.printf "resolved (unexpected)\n"
      | Error msg ->
        let has_sub s sub =
          let sl = String.length s and xl = String.length sub in
          let rec check i = i + xl <= sl &&
            (String.sub s i xl = sub || check (i + 1)) in
          check 0 in
        Printf.printf "error_is_not_found=%b\n" (has_sub msg "not found"))
   | _ -> Printf.printf "unexpected entry count\n");
  [%expect {| error_is_not_found=true |}]

let%expect_test "e2e negative: non-executable host binary detected at resolution" =
  let hub = mk_temp_dir "ext-e2e-noexec" in
  let pkg_dir = hub ^ "/.cn/vendor/packages/cnos.core@3.17.0" in
  let ext_dir = pkg_dir ^ "/extensions/cnos.net.http" in
  let host_dir = ext_dir ^ "/host" in
  Unix.mkdir (hub ^ "/.cn") 0o700;
  Unix.mkdir (hub ^ "/.cn/vendor") 0o700;
  Unix.mkdir (hub ^ "/.cn/vendor/packages") 0o700;
  Unix.mkdir pkg_dir 0o700;
  Unix.mkdir (pkg_dir ^ "/extensions") 0o700;
  Unix.mkdir ext_dir 0o700;
  Unix.mkdir host_dir 0o700;
  (* Write binary but don't set executable bit *)
  let prog = host_dir ^ "/cnos-ext-http" in
  let oc = open_out prog in
  output_string oc "#!/bin/sh\necho hi"; close_out oc;
  Unix.chmod prog 0o644;
  let manifest = {|{
    "schema": "cn.extension.v1",
    "name": "cnos.net.http",
    "version": "1.0.0",
    "interface": "cn.ext.v1",
    "backend": { "kind": "subprocess", "command": ["cnos-ext-http"] },
    "ops": [{ "kind": "http_get", "class": "observe" }],
    "permissions": {},
    "engines": {}
  }|} in
  let oc = open_out (ext_dir ^ "/cn.extension.json") in
  output_string oc manifest; close_out oc;
  let reg = Cn_extension.build_registry ~hub_path:hub ~runtime_version:"3.17.0" () in
  let entries = Cn_extension.all_entries reg in
  (match entries with
   | [e] ->
     (match Cn_extension.resolve_command e with
      | Ok _ -> Printf.printf "resolved (unexpected)\n"
      | Error msg ->
        let has_sub s sub =
          let sl = String.length s and xl = String.length sub in
          let rec check i = i + xl <= sl &&
            (String.sub s i xl = sub || check (i + 1)) in
          check 0 in
        Printf.printf "error_is_not_executable=%b\n" (has_sub msg "not executable"))
   | _ -> Printf.printf "unexpected entry count\n");
  [%expect {| error_is_not_executable=true |}]

let%expect_test "e2e negative: host returns malformed JSON" =
  let hub = mk_temp_dir "ext-e2e-badjson" in
  let pkg_dir = hub ^ "/.cn/vendor/packages/cnos.core@3.17.0" in
  let ext_dir = pkg_dir ^ "/extensions/cnos.bad" in
  let host_dir = ext_dir ^ "/host" in
  Unix.mkdir (hub ^ "/.cn") 0o700;
  Unix.mkdir (hub ^ "/.cn/vendor") 0o700;
  Unix.mkdir (hub ^ "/.cn/vendor/packages") 0o700;
  Unix.mkdir pkg_dir 0o700;
  Unix.mkdir (pkg_dir ^ "/extensions") 0o700;
  Unix.mkdir ext_dir 0o700;
  Unix.mkdir host_dir 0o700;
  (* Write a host that returns garbage *)
  let prog = host_dir ^ "/bad-host" in
  let oc = open_out prog in
  output_string oc "#!/bin/sh\necho 'NOT VALID JSON'\n"; close_out oc;
  Unix.chmod prog 0o755;
  let manifest = {|{
    "schema": "cn.extension.v1",
    "name": "cnos.bad",
    "version": "1.0.0",
    "interface": "cn.ext.v1",
    "backend": { "kind": "subprocess", "command": ["bad-host"] },
    "ops": [{ "kind": "bad_op", "class": "observe" }],
    "permissions": {},
    "engines": {}
  }|} in
  let oc = open_out (ext_dir ^ "/cn.extension.json") in
  output_string oc manifest; close_out oc;
  let reg = Cn_extension.build_registry ~hub_path:hub ~runtime_version:"3.17.0" () in
  (match Cn_extension.lookup_op reg "bad_op" with
   | None -> Printf.printf "op not found (unexpected)\n"
   | Some (entry, _op) ->
     match Cn_extension.resolve_command entry with
     | Error reason -> Printf.printf "resolve error: %s\n" reason
     | Ok cmd ->
       match Cn_ext_host.execute_extension_op ~command:cmd ~op_kind:"bad_op"
               ~arguments:[] () with
       | Ok _ -> Printf.printf "ok (unexpected)\n"
       | Error msg ->
         let has_sub s sub =
           let sl = String.length s and xl = String.length sub in
           let rec check i = i + xl <= sl &&
             (String.sub s i xl = sub || check (i + 1)) in
           check 0 in
         Printf.printf "error_is_parse=%b\n" (has_sub msg "parse error"));
  [%expect {| error_is_parse=true |}]
