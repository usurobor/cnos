(** cn_selfpath_test: ppx_expect tests for hardcoded path removal (#146)

    Three invariants tested:
    1. bin_path resolution chain — $CN_BIN > /proc/self/exe > Sys.executable_name
    2. repo resolution chain — $CN_REPO > cn.json build-time value
    3. No hardcoded literals remain in resolved values *)

(* ============================================================
   Invariant 1: resolve_bin_path respects $CN_BIN override
   ============================================================ *)

let%expect_test "resolve_bin_path: CN_BIN override takes precedence" =
  Unix.putenv "CN_BIN" "/custom/path/cn";
  let result = Cn_agent.resolve_bin_path () in
  Printf.printf "bin_path = %s\n" result;
  (* Clean up *)
  let _ = try Unix.putenv "CN_BIN" ""; () with _ -> () in
  [%expect {| bin_path = /custom/path/cn |}]

let%expect_test "resolve_bin_path: without CN_BIN returns non-empty string" =
  (* Unset CN_BIN to test fallback *)
  let saved = Sys.getenv_opt "CN_BIN" in
  (try Unix.putenv "CN_BIN" "" with _ -> ());
  let result = Cn_agent.resolve_bin_path () in
  Printf.printf "non_empty = %b\n" (String.length result > 0);
  (* Restore *)
  (match saved with Some v -> Unix.putenv "CN_BIN" v | None -> ());
  [%expect {| non_empty = true |}]

(* ============================================================
   Invariant 2: resolve_repo respects $CN_REPO override
   ============================================================ *)

let%expect_test "resolve_repo: CN_REPO override takes precedence" =
  Unix.putenv "CN_REPO" "other-org/other-repo";
  let result = Cn_agent.resolve_repo () in
  Printf.printf "repo = %s\n" result;
  (* Clean up *)
  (try Unix.putenv "CN_REPO" "" with _ -> ());
  [%expect {| repo = other-org/other-repo |}]

let%expect_test "resolve_repo: without CN_REPO returns cn.json value" =
  let saved = Sys.getenv_opt "CN_REPO" in
  (try Unix.putenv "CN_REPO" "" with _ -> ());
  let result = Cn_agent.resolve_repo () in
  Printf.printf "repo = %s\n" result;
  Printf.printf "matches_cnos_repo = %b\n" (result = Cn_lib.cnos_repo);
  (match saved with Some v -> Unix.putenv "CN_REPO" v | None -> ());
  [%expect {|
    repo = usurobor/cnos
    matches_cnos_repo = true
  |}]

(* ============================================================
   Invariant 3: cn_lib.cnos_repo is derived from build-time metadata
   ============================================================ *)

let%expect_test "cnos_repo: build-time value is owner/repo format" =
  let repo = Cn_lib.cnos_repo in
  let has_slash = String.contains repo '/' in
  let non_empty = String.length repo > 0 in
  Printf.printf "repo = %s\n" repo;
  Printf.printf "has_slash = %b\n" has_slash;
  Printf.printf "non_empty = %b\n" non_empty;
  [%expect {|
    repo = usurobor/cnos
    has_slash = true
    non_empty = true
  |}]

(* ============================================================
   Invariant 4: cn_deps derives source from cnos_repo
   ============================================================ *)

let%expect_test "default_first_party_source: derived from cnos_repo" =
  let source = Cn_deps.default_first_party_source in
  let expected = Printf.sprintf "https://github.com/%s.git" Cn_lib.cnos_repo in
  Printf.printf "source = %s\n" source;
  Printf.printf "matches = %b\n" (source = expected);
  [%expect {|
    source = https://github.com/usurobor/cnos.git
    matches = true
  |}]

(* ============================================================
   Negative space: no /usr/local/bin/cn literal in resolved bin_path
   ============================================================ *)

let%expect_test "bin_path: not hardcoded to /usr/local/bin/cn" =
  (* When CN_BIN is set, bin_path must reflect the override.
     When unset, it should use runtime self-location, not a hardcoded path. *)
  Unix.putenv "CN_BIN" "/test/override/cn";
  let result = Cn_agent.resolve_bin_path () in
  Printf.printf "is_override = %b\n" (result = "/test/override/cn");
  Printf.printf "is_not_usr_local = %b\n" (result <> "/usr/local/bin/cn");
  (try Unix.putenv "CN_BIN" "" with _ -> ());
  [%expect {|
    is_override = true
    is_not_usr_local = true
  |}]
