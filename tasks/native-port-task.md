# Task: Port cn CLI to Native OCaml Binary

## Context

cn is a CLI tool for the Coherent Network, currently built as:
- **Source**: OCaml + Melange (JS compiler)
- **Output**: JavaScript bundle run via Node.js
- **Install**: Requires Node.js runtime

We want a **single static binary** with zero runtime dependencies.

## Recent Refactor

cn.ml was just split into 10 modules (branch: `main`):

| Module | Lines | Purpose |
|--------|-------|---------|
| cn.ml | 96 | Thin dispatch (entrypoint) |
| **cn_ffi.ml** | 67 | **Node.js FFI bindings** |
| cn_fmt.ml | 36 | Output formatting |
| cn_hub.ml | 68 | Hub discovery, paths |
| cn_mail.ml | 376 | Inbox/outbox transport |
| cn_gtd.ml | 236 | Thread lifecycle |
| cn_agent.ml | 477 | Agent I/O + queue |
| cn_mca.ml | 164 | Managed concerns |
| cn_commands.ml | 147 | Peers + git commands |
| cn_system.ml | 367 | Setup, update, sync |

**Key insight**: `cn_ffi.ml` is the ONLY module with Node.js FFI bindings. All other modules use `Cn_ffi.*`. 

## Goal

Replace `cn_ffi.ml` with native OCaml implementations. Everything else should work unchanged.

## Principle

**Don't port JS patterns—use idiomatic OCaml.**

```
Wrong: Create OCaml wrapper mimicking Js.String API
Right: Use Str.global_replace, String.lowercase_ascii directly
```

## cn_ffi.ml Current Interface

```ocaml
module Process : sig
  val argv : string array
  val cwd : unit -> string
  val exit : int -> unit
  val env : string Js.Dict.t
end

module Fs : sig
  val exists : string -> bool
  val read : string -> string
  val write : string -> string -> unit
  val append : string -> string -> unit
  val readdir : string -> string list
  val unlink : string -> unit
  val mkdir_p : string -> unit
  val ensure_dir : string -> unit
end

module Path : sig
  val join : string -> string -> string
  val dirname : string -> string
  val basename : string -> string
  val basename_ext : string -> string -> string
end

module Child_process : sig
  val exec_in : cwd:string -> string -> string option
  val exec : string -> string option
end

module Yaml : sig
  val parse : string -> Js.Json.t
  val stringify : Js.Json.t -> string
end

module Json : sig
  val stringify : 'a -> string
end
```

## Native Replacements

### Process
```ocaml
module Process = struct
  let argv = Sys.argv
  let cwd () = Sys.getcwd ()
  let exit = exit
  let getenv_opt = Sys.getenv_opt  (* replaces env dict *)
end
```

### Fs
```ocaml
module Fs = struct
  let exists = Sys.file_exists
  
  let read path =
    In_channel.with_open_text path In_channel.input_all
  
  let write path content =
    Out_channel.with_open_text path (fun oc -> 
      Out_channel.output_string oc content)
  
  let append path content =
    let oc = open_out_gen [Open_append; Open_creat; Open_text] 0o644 path in
    output_string oc content;
    close_out oc
  
  let readdir path = Sys.readdir path |> Array.to_list
  
  let unlink = Sys.remove
  
  let rec mkdir_p path =
    if path <> "" && not (Sys.file_exists path) then begin
      mkdir_p (Filename.dirname path);
      try Unix.mkdir path 0o755 
      with Unix.Unix_error (Unix.EEXIST, _, _) -> ()
    end
  
  let ensure_dir path = if not (exists path) then mkdir_p path
end
```

### Path
```ocaml
module Path = struct
  let join = Filename.concat
  let dirname = Filename.dirname
  let basename = Filename.basename
  let basename_ext path ext = Filename.remove_extension (basename path)
end
```

### Child_process
```ocaml
module Child_process = struct
  let exec_in ~cwd cmd =
    let old_cwd = Sys.getcwd () in
    try
      Sys.chdir cwd;
      let ic = Unix.open_process_in cmd in
      let output = In_channel.input_all ic in
      let status = Unix.close_process_in ic in
      Sys.chdir old_cwd;
      match status with
      | Unix.WEXITED 0 -> Some output
      | _ -> None
    with _ -> Sys.chdir old_cwd; None

  let exec cmd =
    try
      let ic = Unix.open_process_in cmd in
      let output = In_channel.input_all ic in
      let status = Unix.close_process_in ic in
      match status with
      | Unix.WEXITED 0 -> Some output
      | _ -> None
    with _ -> None
end
```

### Yaml/Json (simplified)
For now, use simple string parsing for the limited YAML we actually read (peers.md frontmatter). Full YAML library can be added later if needed.

## String Operations to Replace

In modules that use `Js.String`:

| JS Pattern | Native OCaml |
|------------|--------------|
| `Js.String.toLowerCase s` | `String.lowercase_ascii s` |
| `Js.String.replaceByRe ~regexp:[%mel.re "/x/g"] ~replacement:"y" s` | `Str.global_replace (Str.regexp "x") "y" s` |
| `Js.String.slice ~start ~end_ s` | `String.sub s start (end_ - start)` |
| `Js.String.match_ ~regexp s` | `Str.string_match (Str.regexp ...) s 0` |

## Implementation Steps

1. **Create `cn_native.ml`** — native implementations of Cn_ffi interface
2. **Update modules** — replace `Js.String.*` patterns with `Str.*` / stdlib
3. **Create native dune stanza** — build native binary alongside Melange
4. **Test** — verify all commands work identically
5. **Update install.sh** — install native binary

## Dune Configuration

Add to `tools/src/cn/dune`:

```dune
; Native OCaml binary
(executable
 (name cn_native)
 (public_name cn)
 (modules cn cn_native cn_lib cn_fmt cn_hub cn_mail cn_gtd 
          cn_agent cn_mca cn_commands cn_system)
 (libraries unix str)
 (modes native))
```

## Verification

After porting, these must work identically:

```bash
cn --version
cn status
cn doctor
cn sync
cn send pi "test message"
cn in
```

## Constraints

- **No new dependencies** — stdlib + unix + str only
- **Same CLI interface** — all commands unchanged
- **Backwards compatible** — Melange build still works (for now)

## Branch

Work on: `task/native-port` (rebase onto latest main first)

## Deliverables

1. `cn_native.ml` — native FFI implementation
2. Updated modules with Str/stdlib replacements
3. Native dune build configuration
4. Passing tests
5. Updated install.sh for native binary
