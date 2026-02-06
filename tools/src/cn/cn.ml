(** cn: Main CLI entrypoint (Melange -> Node.js).
    
    Follows FUNCTIONAL.md:
    - Pipelines over sequences
    - Fold over mutation
    - Option over exceptions
    - Effects at boundaries *)

open Cn_lib

(* === Node.js FFI Modules === *)

module Process = struct
  external argv : string array = "argv" [@@mel.scope "process"]
  external cwd : unit -> string = "cwd" [@@mel.scope "process"]
  external exit : int -> unit = "exit" [@@mel.scope "process"]
  external env : string Js.Dict.t = "env" [@@mel.scope "process"]
end

module Fs = struct
  external exists_sync : string -> bool = "existsSync" [@@mel.module "fs"]
  external read_file_sync : string -> string -> string = "readFileSync" [@@mel.module "fs"]
  external write_file_sync : string -> string -> unit = "writeFileSync" [@@mel.module "fs"]
  external append_file_sync : string -> string -> unit = "appendFileSync" [@@mel.module "fs"]
  external unlink_sync : string -> unit = "unlinkSync" [@@mel.module "fs"]
  external readdir_sync : string -> string array = "readdirSync" [@@mel.module "fs"]
  external mkdir_sync : string -> < recursive : bool > Js.t -> unit = "mkdirSync" [@@mel.module "fs"]
  
  let exists = exists_sync
  let read path = read_file_sync path "utf8"
  let write = write_file_sync
  let append = append_file_sync
  let unlink = unlink_sync
  let readdir path = readdir_sync path |> Array.to_list
  let mkdir_p path = mkdir_sync path [%mel.obj { recursive = true }]
  let ensure_dir path = if not (exists path) then mkdir_p path
end

module Path = struct
  external join : string -> string -> string = "join" [@@mel.module "path"]
  external dirname : string -> string = "dirname" [@@mel.module "path"]
  external basename : string -> string = "basename" [@@mel.module "path"]
  external basename_ext : string -> string -> string = "basename" [@@mel.module "path"]
end

module Child_process = struct
  external exec_sync : string -> < cwd : string ; encoding : string ; stdio : string array > Js.t -> string = "execSync" [@@mel.module "child_process"]
  external exec_sync_simple : string -> < encoding : string > Js.t -> string = "execSync" [@@mel.module "child_process"]
  
  let exec_in ~cwd cmd =
    try Some (exec_sync cmd [%mel.obj { cwd; encoding = "utf8"; stdio = [|"pipe"; "pipe"; "pipe"|] }])
    with _ -> None
  
  let exec cmd =
    try Some (exec_sync_simple cmd [%mel.obj { encoding = "utf8" }])
    with _ -> None
end

module Json = struct
  external stringify : 'a -> string = "stringify" [@@mel.scope "JSON"]
end

(* === Time === *)

let now_iso () = Js.Date.toISOString (Js.Date.make ())

(* === Output === *)

let no_color = Js.Dict.get Process.env "NO_COLOR" |> Option.is_some

let color code s = if no_color then s else Printf.sprintf "\027[%sm%s\027[0m" code s
let green = color "32"
let red = color "31"
let yellow = color "33"
let cyan = color "36"
let dim = color "2"

let ok msg = green "✓ " ^ msg
let fail msg = red "✗ " ^ msg
let warn msg = yellow "⚠ " ^ msg
let info = cyan

(* === Hub Detection === *)

let rec find_hub_path dir =
  match dir with
  | "/" -> None
  | _ ->
      let has_config = Fs.exists (Path.join dir ".cn/config.json") in
      let has_peers = Fs.exists (Path.join dir "state/peers.md") in
      if has_config || has_peers then Some dir
      else find_hub_path (Path.dirname dir)

(* === Logging === *)

let log_action hub_path action details =
  let logs_dir = Path.join hub_path "logs" in
  Fs.ensure_dir logs_dir;
  let entry = [%mel.obj { ts = now_iso (); action; details }] in
  Fs.append (Path.join logs_dir "cn.log") (Json.stringify entry ^ "\n")

(* === Peers === *)

let load_peers hub_path =
  let peers_path = Path.join hub_path "state/peers.md" in
  if Fs.exists peers_path then parse_peers_md (Fs.read peers_path)
  else []

(* === Helpers === *)

let is_md_file = ends_with ~suffix:".md"
let split_lines s = String.split_on_char '\n' s |> List.filter non_empty

(* === Result Types === *)

type branch_info = { peer: string; branch: string }

(* === Inbox Operations === *)

let get_peer_branches hub_path peer_name =
  Printf.sprintf "git branch -r | grep 'origin/%s/' | sed 's/.*origin\\///'" peer_name
  |> Child_process.exec_in ~cwd:hub_path
  |> Option.map split_lines
  |> Option.value ~default:[]
  |> List.map (fun branch -> { peer = peer_name; branch })

let inbox_check hub_path name =
  let _ = Child_process.exec_in ~cwd:hub_path "git fetch origin" in
  let peers = load_peers hub_path in
  
  print_endline (info (Printf.sprintf "Checking inbox for %s..." name));
  
  let total = peers |> List.fold_left (fun acc peer ->
    match peer.kind with
    | Some "template" -> acc
    | _ ->
        let branches = get_peer_branches hub_path peer.name in
        (match branches with
         | [] -> print_endline (dim (Printf.sprintf "  %s: no inbound" peer.name))
         | bs ->
             print_endline (warn (Printf.sprintf "From %s: %d inbound" peer.name (List.length bs)));
             bs |> List.iter (fun b -> print_endline (Printf.sprintf "  ← %s" b.branch)));
        acc + List.length branches
  ) 0 in
  
  if total = 0 then print_endline (ok "Inbox clear")

let materialize_branch hub_path inbox_dir peer_name branch =
  let diff_cmd = Printf.sprintf "git diff main...origin/%s --name-only 2>/dev/null || git diff master...origin/%s --name-only" branch branch in
  Child_process.exec_in ~cwd:hub_path diff_cmd
  |> Option.map split_lines
  |> Option.value ~default:[]
  |> List.filter is_md_file
  |> List.filter_map (fun file ->
      let show_cmd = Printf.sprintf "git show origin/%s:%s" branch file in
      match Child_process.exec_in ~cwd:hub_path show_cmd with
      | None -> None
      | Some content ->
          let branch_slug = branch |> String.split_on_char '/' |> List.rev |> List.hd in
          let inbox_file = Printf.sprintf "%s-%s.md" peer_name branch_slug in
          let inbox_path = Path.join inbox_dir inbox_file in
          if Fs.exists inbox_path then None
          else begin
            let meta = [("from", peer_name); ("branch", branch); ("file", file); ("received", now_iso ())] in
            Fs.write inbox_path (update_frontmatter content meta);
            log_action hub_path "inbox.materialize" inbox_file;
            Some inbox_file
          end)

let inbox_process hub_path =
  print_endline (info "Processing inbox...");
  let inbox_dir = Path.join hub_path "threads/inbox" in
  Fs.ensure_dir inbox_dir;
  
  let peers = load_peers hub_path in
  let materialized = peers |> List.fold_left (fun acc peer ->
    match peer.kind with
    | Some "template" -> acc
    | _ ->
        let branches = get_peer_branches hub_path peer.name in
        let files = branches |> List.concat_map (fun b ->
          materialize_branch hub_path inbox_dir peer.name b.branch)
        in
        acc @ files
  ) [] in
  
  materialized |> List.iter (fun f -> print_endline (ok (Printf.sprintf "Materialized: %s" f)));
  match materialized with
  | [] -> print_endline (info "No new threads to materialize")
  | fs -> print_endline (ok (Printf.sprintf "Processed %d thread(s)" (List.length fs)))

(* === Outbox Operations === *)

let outbox_check hub_path =
  let outbox_dir = Path.join hub_path "threads/outbox" in
  if not (Fs.exists outbox_dir) then print_endline (ok "Outbox clear")
  else
    let threads = Fs.readdir outbox_dir |> List.filter is_md_file in
    match threads with
    | [] -> print_endline (ok "Outbox clear")
    | ts ->
        print_endline (warn (Printf.sprintf "%d pending send(s):" (List.length ts)));
        ts |> List.iter (fun f ->
          let content = Fs.read (Path.join outbox_dir f) in
          let meta = parse_frontmatter content in
          let to_peer = meta |> List.find_map (fun (k, v) -> if k = "to" then Some v else None)
            |> Option.value ~default:"(no recipient)" in
          print_endline (Printf.sprintf "  → %s: %s" to_peer f))

let send_thread hub_path name peers outbox_dir sent_dir file =
  let file_path = Path.join outbox_dir file in
  let content = Fs.read file_path in
  let meta = parse_frontmatter content in
  
  let to_peer = meta |> List.find_map (fun (k, v) -> if k = "to" then Some v else None) in
  
  match to_peer with
  | None ->
      log_action hub_path "outbox.skip" (Printf.sprintf "thread:%s reason:no recipient" file);
      print_endline (warn (Printf.sprintf "Skipping %s: no 'to:' in frontmatter" file));
      None
  | Some to_name ->
      let peer = peers |> List.find_opt (fun p -> p.name = to_name) in
      match peer with
      | None ->
          log_action hub_path "outbox.skip" (Printf.sprintf "thread:%s to:%s reason:unknown peer" file to_name);
          print_endline (fail (Printf.sprintf "Unknown peer: %s" to_name));
          None
      | Some p when p.clone = None ->
          log_action hub_path "outbox.skip" (Printf.sprintf "thread:%s to:%s reason:no clone path" file to_name);
          print_endline (fail (Printf.sprintf "No clone path for peer: %s" to_name));
          None
      | Some p ->
          let clone_path = Option.get p.clone in
          let thread_name = Path.basename_ext file ".md" in
          let branch_name = Printf.sprintf "%s/%s" name thread_name in
          
          match Child_process.exec_in ~cwd:clone_path "git checkout main 2>/dev/null || git checkout master" with
          | None ->
              log_action hub_path "outbox.send" (Printf.sprintf "to:%s thread:%s error:checkout failed" to_name file);
              print_endline (fail (Printf.sprintf "Failed to send %s" file));
              None
          | Some _ ->
              let _ = Child_process.exec_in ~cwd:clone_path "git pull --ff-only 2>/dev/null || true" in
              let _ = Child_process.exec_in ~cwd:clone_path (Printf.sprintf "git checkout -b %s 2>/dev/null || git checkout %s" branch_name branch_name) in
              
              let peer_thread_dir = Path.join clone_path "threads/adhoc" in
              Fs.ensure_dir peer_thread_dir;
              Fs.write (Path.join peer_thread_dir file) content;
              let _ = Child_process.exec_in ~cwd:clone_path (Printf.sprintf "git add 'threads/adhoc/%s'" file) in
              let _ = Child_process.exec_in ~cwd:clone_path (Printf.sprintf "git commit -m '%s: %s'" name thread_name) in
              let _ = Child_process.exec_in ~cwd:clone_path (Printf.sprintf "git push -u origin %s -f" branch_name) in
              let _ = Child_process.exec_in ~cwd:clone_path "git checkout main 2>/dev/null || git checkout master" in
              
              Fs.write (Path.join sent_dir file) (update_frontmatter content [("sent", now_iso ())]);
              Fs.unlink file_path;
              
              log_action hub_path "outbox.send" (Printf.sprintf "to:%s thread:%s" to_name file);
              print_endline (ok (Printf.sprintf "Sent to %s: %s" to_name file));
              Some file

let outbox_flush hub_path name =
  let outbox_dir = Path.join hub_path "threads/outbox" in
  let sent_dir = Path.join hub_path "threads/sent" in
  
  if not (Fs.exists outbox_dir) then print_endline (ok "Outbox clear")
  else begin
    Fs.ensure_dir sent_dir;
    let threads = Fs.readdir outbox_dir |> List.filter is_md_file in
    match threads with
    | [] -> print_endline (ok "Outbox clear")
    | ts ->
        print_endline (info (Printf.sprintf "Flushing %d thread(s)..." (List.length ts)));
        let peers = load_peers hub_path in
        let _ = ts |> List.filter_map (send_thread hub_path name peers outbox_dir sent_dir) in
        print_endline (ok "Outbox flush complete")
  end

(* === Next Inbox Item === *)

let get_next_inbox_item hub_path =
  let inbox_dir = Path.join hub_path "threads/inbox" in
  if not (Fs.exists inbox_dir) then None
  else
    Fs.readdir inbox_dir
    |> List.filter is_md_file
    |> List.sort String.compare
    |> function
      | [] -> None
      | file :: _ ->
          let file_path = Path.join inbox_dir file in
          let content = Fs.read file_path in
          let meta = parse_frontmatter content in
          let from = meta |> List.find_map (fun (k, v) -> if k = "from" then Some v else None)
            |> Option.value ~default:"unknown" in
          Some (Path.basename_ext file ".md", "inbox", from, content)

let run_next hub_path =
  match get_next_inbox_item hub_path with
  | None -> print_endline "(inbox empty)"
  | Some (id, cadence, from, content) ->
      Printf.printf "[cadence: %s]\n[from: %s]\n[id: %s]\n\n%s\n" cadence from id content

(* === GTD Operations === *)

let find_thread hub_path thread_id =
  let locations = ["inbox"; "outbox"; "doing"; "deferred"; "daily"; "adhoc"] in
  if String.contains thread_id '/' then
    let path = Path.join hub_path (Printf.sprintf "threads/%s.md" thread_id) in
    if Fs.exists path then Some path else None
  else
    locations |> List.find_map (fun loc ->
      let path = Path.join hub_path (Printf.sprintf "threads/%s/%s.md" loc thread_id) in
      if Fs.exists path then Some path else None)

let gtd_delete hub_path thread_id =
  match find_thread hub_path thread_id with
  | None -> print_endline (fail (Printf.sprintf "Thread not found: %s" thread_id))
  | Some path ->
      Fs.unlink path;
      log_action hub_path "gtd.delete" thread_id;
      print_endline (ok (Printf.sprintf "Deleted: %s" thread_id))

let gtd_defer hub_path thread_id until =
  match find_thread hub_path thread_id with
  | None -> print_endline (fail (Printf.sprintf "Thread not found: %s" thread_id))
  | Some path ->
      let deferred_dir = Path.join hub_path "threads/deferred" in
      Fs.ensure_dir deferred_dir;
      let content = Fs.read path in
      let until_str = Option.value until ~default:"unspecified" in
      Fs.write (Path.join deferred_dir (Path.basename path)) 
        (update_frontmatter content [("deferred", now_iso ()); ("until", until_str)]);
      Fs.unlink path;
      log_action hub_path "gtd.defer" (Printf.sprintf "%s until:%s" thread_id until_str);
      let suffix = match until with Some u -> " until " ^ u | None -> "" in
      print_endline (ok (Printf.sprintf "Deferred: %s%s" thread_id suffix))

let gtd_delegate hub_path name thread_id peer =
  match find_thread hub_path thread_id with
  | None -> print_endline (fail (Printf.sprintf "Thread not found: %s" thread_id))
  | Some path ->
      let outbox_dir = Path.join hub_path "threads/outbox" in
      Fs.ensure_dir outbox_dir;
      let content = Fs.read path in
      Fs.write (Path.join outbox_dir (Path.basename path))
        (update_frontmatter content [("to", peer); ("delegated", now_iso ()); ("delegated-by", name)]);
      Fs.unlink path;
      log_action hub_path "gtd.delegate" (Printf.sprintf "%s to:%s" thread_id peer);
      print_endline (ok (Printf.sprintf "Delegated to %s: %s" peer thread_id));
      print_endline (info "Run \"cn sync\" to send")

let gtd_do hub_path thread_id =
  match find_thread hub_path thread_id with
  | None -> print_endline (fail (Printf.sprintf "Thread not found: %s" thread_id))
  | Some path ->
      let doing_dir = Path.join hub_path "threads/doing" in
      Fs.ensure_dir doing_dir;
      let content = Fs.read path in
      Fs.write (Path.join doing_dir (Path.basename path))
        (update_frontmatter content [("started", now_iso ())]);
      Fs.unlink path;
      log_action hub_path "gtd.do" thread_id;
      print_endline (ok (Printf.sprintf "Started: %s" thread_id))

let gtd_done hub_path thread_id =
  match find_thread hub_path thread_id with
  | None -> print_endline (fail (Printf.sprintf "Thread not found: %s" thread_id))
  | Some path ->
      let archived_dir = Path.join hub_path "threads/archived" in
      Fs.ensure_dir archived_dir;
      let content = Fs.read path in
      Fs.write (Path.join archived_dir (Path.basename path))
        (update_frontmatter content [("completed", now_iso ())]);
      Fs.unlink path;
      log_action hub_path "gtd.done" thread_id;
      print_endline (ok (Printf.sprintf "Completed: %s → archived" thread_id))

(* === Read Thread === *)

let run_read hub_path thread_id =
  match find_thread hub_path thread_id with
  | None -> print_endline (fail (Printf.sprintf "Thread not found: %s" thread_id))
  | Some path ->
      let content = Fs.read path in
      let cadence = cadence_of_path path |> string_of_cadence in
      let meta = parse_frontmatter content in
      Printf.printf "[cadence: %s]\n" cadence;
      meta |> List.find_map (fun (k, v) -> if k = "from" then Some v else None)
        |> Option.iter (Printf.printf "[from: %s]\n");
      meta |> List.find_map (fun (k, v) -> if k = "to" then Some v else None)
        |> Option.iter (Printf.printf "[to: %s]\n");
      print_endline "";
      print_endline content

(* === Inbox/Outbox List === *)

let run_inbox_list hub_path =
  let inbox_dir = Path.join hub_path "threads/inbox" in
  if not (Fs.exists inbox_dir) then print_endline "(empty)"
  else
    match Fs.readdir inbox_dir |> List.filter is_md_file with
    | [] -> print_endline "(empty)"
    | ts -> ts |> List.iter (fun f ->
        let id = Path.basename_ext f ".md" in
        let meta = Fs.read (Path.join inbox_dir f) |> parse_frontmatter in
        let from = meta |> List.find_map (fun (k, v) -> if k = "from" then Some v else None)
          |> Option.value ~default:"unknown" in
        Printf.printf "%s/%s\n" from id)

let run_outbox_list hub_path =
  let outbox_dir = Path.join hub_path "threads/outbox" in
  if not (Fs.exists outbox_dir) then print_endline "(empty)"
  else
    match Fs.readdir outbox_dir |> List.filter is_md_file with
    | [] -> print_endline "(empty)"
    | ts -> ts |> List.iter (fun f ->
        let id = Path.basename_ext f ".md" in
        let meta = Fs.read (Path.join outbox_dir f) |> parse_frontmatter in
        let to_peer = meta |> List.find_map (fun (k, v) -> if k = "to" then Some v else None)
          |> Option.value ~default:"unknown" in
        Printf.printf "→ %s  \"%s\"\n" to_peer id)

(* === Git Operations === *)

let run_commit hub_path name msg =
  match Child_process.exec_in ~cwd:hub_path "git status --porcelain" with
  | Some status when String.trim status = "" -> print_endline (info "Nothing to commit")
  | _ ->
      let message = match msg with
        | Some m -> m
        | None -> Printf.sprintf "%s: auto-commit %s" name (String.sub (now_iso ()) 0 10)
      in
      let _ = Child_process.exec_in ~cwd:hub_path "git add -A" in
      let escaped = Js.String.replaceByRe ~regexp:[%mel.re "/\"/g"] ~replacement:"\\\"" message in
      match Child_process.exec_in ~cwd:hub_path (Printf.sprintf "git commit -m \"%s\"" escaped) with
      | Some _ ->
          log_action hub_path "commit" message;
          print_endline (ok (Printf.sprintf "Committed: %s" message))
      | None ->
          log_action hub_path "commit" (Printf.sprintf "error:%s" message);
          print_endline (fail "Commit failed")

let run_push hub_path =
  match Child_process.exec_in ~cwd:hub_path "git branch --show-current" with
  | None -> print_endline (fail "Could not determine current branch")
  | Some branch ->
      let branch = String.trim branch in
      match Child_process.exec_in ~cwd:hub_path (Printf.sprintf "git push origin %s" branch) with
      | Some _ ->
          log_action hub_path "push" branch;
          print_endline (ok (Printf.sprintf "Pushed to origin/%s" branch))
      | None ->
          log_action hub_path "push" "error";
          print_endline (fail "Push failed")

(* === Send Message === *)

let run_send hub_path peer message =
  let outbox_dir = Path.join hub_path "threads/outbox" in
  Fs.ensure_dir outbox_dir;
  
  let slug = 
    message 
    |> Js.String.slice ~start:0 ~end_:30 
    |> Js.String.toLowerCase 
    |> Js.String.replaceByRe ~regexp:[%mel.re "/[^a-z0-9]+/g"] ~replacement:"-"
    |> Js.String.replaceByRe ~regexp:[%mel.re "/^-|-$/g"] ~replacement:""
  in
  let file_name = slug ^ ".md" in
  let first_line = message |> String.split_on_char '\n' |> List.hd in
  let content = Printf.sprintf "---\nto: %s\ncreated: %s\n---\n\n# %s\n\n%s\n" 
    peer (now_iso ()) first_line message in
  
  Fs.write (Path.join outbox_dir file_name) content;
  log_action hub_path "send" (Printf.sprintf "to:%s thread:%s" peer slug);
  print_endline (ok (Printf.sprintf "Created message to %s: %s" peer slug));
  print_endline (info "Run \"cn sync\" to send")

(* === Reply === *)

let run_reply hub_path thread_id message =
  match find_thread hub_path thread_id with
  | None -> print_endline (fail (Printf.sprintf "Thread not found: %s" thread_id))
  | Some path ->
      let reply = Printf.sprintf "\n\n## Reply (%s)\n\n%s" (now_iso ()) message in
      Fs.append path reply;
      log_action hub_path "reply" (Printf.sprintf "thread:%s" thread_id);
      print_endline (ok (Printf.sprintf "Replied to %s" thread_id))

(* === Status === *)

let run_status hub_path name =
  print_endline (info (Printf.sprintf "cn hub: %s" name));
  print_endline "";
  Printf.printf "hub..................... %s\n" (green "✓");
  Printf.printf "name.................... %s %s\n" (green "✓") name;
  Printf.printf "path.................... %s %s\n" (green "✓") hub_path;
  print_endline "";
  print_endline (dim (Printf.sprintf "[status] ok version=%s" version))

(* === Doctor === *)

type check_result = { name: string; passed: bool; value: string }

let run_doctor hub_path =
  Printf.printf "cn v%s\n" version;
  print_endline (info "Checking health...");
  print_endline "";
  
  let checks = [
    (match Child_process.exec "git --version" with
     | Some v -> { name = "git"; passed = true; value = Js.String.replace ~search:"git version " ~replacement:"" (String.trim v) }
     | None -> { name = "git"; passed = false; value = "not installed" });
    
    (match Child_process.exec "git config user.name" with
     | Some v -> { name = "git user.name"; passed = true; value = String.trim v }
     | None -> { name = "git user.name"; passed = false; value = "not set" });
    
    (match Child_process.exec "git config user.email" with
     | Some v -> { name = "git user.email"; passed = true; value = String.trim v }
     | None -> { name = "git user.email"; passed = false; value = "not set" });
    
    { name = "hub directory"; passed = Fs.exists hub_path; 
      value = if Fs.exists hub_path then "exists" else "not found" };
    
    (let p = Path.join hub_path ".cn/config.json" in
     { name = ".cn/config.json"; passed = Fs.exists p; 
       value = if Fs.exists p then "exists" else "missing" });
    
    (let p = Path.join hub_path "spec/SOUL.md" in
     { name = "spec/SOUL.md"; passed = Fs.exists p; 
       value = if Fs.exists p then "exists" else "missing (optional)" });
    
    (let p = Path.join hub_path "state/peers.md" in
     if Fs.exists p then
       let count = Js.String.match_ ~regexp:[%mel.re "/- name:/g"] (Fs.read p)
         |> Option.map Array.length |> Option.value ~default:0 in
       { name = "state/peers.md"; passed = true; value = Printf.sprintf "%d peer(s)" count }
     else { name = "state/peers.md"; passed = false; value = "missing" });
    
    (match Child_process.exec_in ~cwd:hub_path "git remote get-url origin" with
     | Some _ -> { name = "origin remote"; passed = true; value = "configured" }
     | None -> { name = "origin remote"; passed = false; value = "not configured" });
  ] in
  
  let width = 22 in
  checks |> List.iter (fun c ->
    let dots = String.make (max 1 (width - String.length c.name)) '.' in
    let status = if c.passed then green ("✓ " ^ c.value) else red ("✗ " ^ c.value) in
    Printf.printf "%s%s %s\n" c.name dots status);
  
  print_endline "";
  let fails = checks |> List.filter (fun c -> not c.passed) |> List.length in
  let oks = List.length checks - fails in
  (if fails = 0 then print_endline (ok "All critical checks passed.")
   else print_endline (fail (Printf.sprintf "%d issue(s) found." fails)));
  print_endline (dim (Printf.sprintf "[status] ok=%d warn=0 fail=%d version=%s" oks fails version))

(* === Process (Actor Loop) === *)

let run_process hub_path =
  print_endline (info "Actor loop: checking for inbox items...");
  
  let input_path = Path.join hub_path "state/input.md" in
  
  if Fs.exists input_path then begin
    print_endline (warn "state/input.md exists - previous item not processed");
    print_endline (info "Agent should clear input.md when done");
    Process.exit 1
  end;
  
  match get_next_inbox_item hub_path with
  | None -> print_endline (ok "Inbox empty - nothing to process")
  | Some (id, _cadence, from, content) ->
      print_endline (info (Printf.sprintf "Processing: %s (from %s)" id from));
      
      let state_dir = Path.join hub_path "state" in
      Fs.ensure_dir state_dir;
      
      let input_content = Printf.sprintf "---\nid: %s\nfrom: %s\nqueued: %s\n---\n\n%s" 
        id from (now_iso ()) content in
      Fs.write input_path input_content;
      
      log_action hub_path "process.queue" (Printf.sprintf "id:%s from:%s" id from);
      print_endline (ok (Printf.sprintf "Wrote to state/input.md: %s" id));
      
      print_endline (info "Triggering OpenClaw wake...");
      let wake_text = Printf.sprintf "cn input ready: %s from %s" id from in
      let wake_cmd = Printf.sprintf "curl -s -X POST http://localhost:18789/cron/wake -H 'Content-Type: application/json' -d '{\"text\":\"%s\",\"mode\":\"now\"}'" wake_text in
      (match Child_process.exec wake_cmd with
       | Some _ -> print_endline (ok "Wake triggered")
       | None -> print_endline (warn "Wake trigger failed - is OpenClaw running?"));
      
      print_endline (info "Actor loop complete. Agent will process input.md and clear when done.")

(* === Sync === *)

let run_sync hub_path name =
  print_endline (info "Syncing...");
  inbox_check hub_path name;
  inbox_process hub_path;
  outbox_flush hub_path name;
  print_endline (ok "Sync complete")

(* === Main === *)

let () =
  let args = Process.argv |> Array.to_list |> List.tl |> List.tl in
  let flags, cmd_args = parse_flags args in
  let _ = flags in
  
  match parse_command cmd_args with
  | None ->
      (match cmd_args with cmd :: _ -> print_endline (fail (Printf.sprintf "Unknown command: %s" cmd)) | [] -> ());
      print_endline help_text;
      Process.exit 1
  | Some Help -> print_endline help_text
  | Some Version -> Printf.printf "cn %s\n" version
  | Some (Init name) ->
      let hub_name = Option.value name ~default:(Path.basename (Process.cwd ())) in
      print_endline (info (Printf.sprintf "Initializing hub: %s" hub_name));
      print_endline (warn "Not yet implemented")
  | Some cmd ->
      match find_hub_path (Process.cwd ()) with
      | None ->
          print_endline (fail "Not in a cn hub.");
          print_endline "";
          print_endline "Either:";
          print_endline "  1) cd into an existing hub (cn-sigma, cn-pi, etc.)";
          print_endline "  2) cn init <name> to create a new one";
          Process.exit 1
      | Some hub_path ->
          let name = derive_name hub_path in
          match cmd with
          | Status -> run_status hub_path name
          | Doctor -> run_doctor hub_path
          | Inbox Inbox_check -> inbox_check hub_path name
          | Inbox Inbox_process -> inbox_process hub_path
          | Inbox Inbox_flush -> print_endline (warn "inbox flush not implemented")
          | Outbox Outbox_check -> outbox_check hub_path
          | Outbox Outbox_flush -> outbox_flush hub_path name
          | Sync -> run_sync hub_path name
          | Next -> run_next hub_path
          | Process -> run_process hub_path
          | Read t -> run_read hub_path t
          | Reply (t, m) -> run_reply hub_path t m
          | Send (p, m) -> run_send hub_path p m
          | Gtd (GtdDelete t) -> gtd_delete hub_path t
          | Gtd (GtdDefer (t, u)) -> gtd_defer hub_path t u
          | Gtd (GtdDelegate (t, p)) -> gtd_delegate hub_path name t p
          | Gtd (GtdDo t) -> gtd_do hub_path t
          | Gtd (GtdDone t) -> gtd_done hub_path t
          | Commit msg -> run_commit hub_path name msg
          | Push -> run_push hub_path
          | Save msg -> run_commit hub_path name msg; run_push hub_path
          | Peer _ -> print_endline (warn "peer commands not yet implemented")
          | Help | Version | Init _ -> () (* handled above *)
