(** cn_mail.ml — Inbox/outbox mail transport

    Packet-based materialization (#150), inbox check/process/flush,
    outbox check/flush/send. *)

open Cn_lib

(* === Inbox Operations === *)

let inbox_check hub_path _name =
  let peers = Cn_hub.load_peers hub_path in

  print_endline (Cn_fmt.info "Checking inbox for packet refs...");

  let total = peers |> List.fold_left (fun acc peer ->
    match peer.kind, peer.clone with
    | Some "template", _ -> acc
    | _, None ->
        print_endline (Cn_fmt.dim (Printf.sprintf "  %s: no clone path" peer.name));
        acc
    | _, Some clone_path ->
        if not (Cn_ffi.Fs.exists clone_path) then begin
          print_endline (Cn_fmt.dim (Printf.sprintf "  %s: clone not found" peer.name));
          acc
        end else begin
          let _ = Cn_ffi.Child_process.exec_in ~cwd:clone_path "git fetch origin --prune" in
          let _ = Cn_ffi.Child_process.exec_in ~cwd:clone_path
            (Printf.sprintf "git fetch origin '+refs/cn/msg/%s/*:refs/remotes/origin/cn/msg/%s/*' 2>/dev/null"
              peer.name peer.name) in
          let refs = Cn_packet.list_packet_refs ~cwd:clone_path ~sender:peer.name in
          (match refs with
           | [] -> print_endline (Cn_fmt.dim (Printf.sprintf "  %s: no inbound" peer.name))
           | rs ->
               print_endline (Cn_fmt.warn (Printf.sprintf "From %s: %d inbound packet(s)" peer.name (List.length rs)));
               rs |> List.iter (fun r -> print_endline (Printf.sprintf "  ← %s" r)));
          acc + List.length refs
        end
  ) 0 in

  if total = 0 then print_endline (Cn_fmt.ok "Inbox clear")

(* #150: materialize validated packet refs.
   Packet refs live under refs/cn/msg/{sender}/{msg_id}. Each ref points to
   a root commit with packet/envelope.json + packet/message.md. Validation
   pipeline runs all checks before any inbox write. *)
let materialize_packet ~clone_path ~hub_path ~inbox_dir ~local_name ~peer_name ref_name =
  match Cn_packet.parse_packet_ref ref_name with
  | None ->
      Cn_trace.gemit ~component:"mail" ~layer:Body
        ~event:"packet.rejected" ~severity:Warn ~status:Degraded
        ~reason_code:"invalid_ref"
        ~details:["ref", Cn_json.String ref_name; "peer", Cn_json.String peer_name] ();
      None
  | Some (ref_sender, ref_msg_id) ->
      (* Convert refs/cn/msg/... to origin remote ref for reading *)
      let remote_ref = Printf.sprintf "origin/cn/msg/%s/%s" ref_sender ref_msg_id in

      (* Dedup check *)
      let index_path = Cn_ffi.Path.join hub_path "state/inbound-index.json" in
      let index = Cn_packet.load_dedup_index index_path in

      match Cn_packet.read_git_packet ~cwd:clone_path ~ref_name:remote_ref with
      | Error e ->
          Cn_trace.gemit ~component:"mail" ~layer:Body
            ~event:"packet.rejected" ~severity:Warn ~status:Degraded
            ~reason_code:e.reason_code
            ~details:["ref", Cn_json.String ref_name;
                       "peer", Cn_json.String peer_name;
                       "reason", Cn_json.String e.reason] ();
          print_endline (Cn_fmt.fail (Printf.sprintf "Packet rejected [%s]: %s" ref_name e.reason));
          None
      | Ok (envelope_json, payload_content) ->
          match Cn_packet.validate_packet ~ref_sender ~ref_msg_id
                  ~local_name ~envelope_json ~payload_content with
          | Error e ->
              Cn_trace.gemit ~component:"mail" ~layer:Body
                ~event:"packet.rejected" ~severity:Warn ~status:Degraded
                ~reason_code:e.reason_code
                ~details:["ref", Cn_json.String ref_name;
                           "msg_id", Cn_json.String ref_msg_id;
                           "peer", Cn_json.String peer_name;
                           "reason", Cn_json.String e.reason] ();
              print_endline (Cn_fmt.fail (Printf.sprintf "Packet rejected [%s]: %s" ref_msg_id e.reason));
              None
          | Ok (env, content) ->
              let payload_sha = env.Cn_packet.payload_sha256 in
              (* Dedup/equivocation check *)
              match Cn_packet.check_dedup index
                      ~msg_id:env.Cn_packet.msg_id
                      ~sender:env.Cn_packet.pkt_sender
                      ~payload_sha256:payload_sha with
              | Cn_packet.Duplicate ->
                  Cn_trace.gemit ~component:"mail" ~layer:Body
                    ~event:"packet.duplicate" ~severity:Info ~status:Ok_
                    ~details:["msg_id", Cn_json.String env.Cn_packet.msg_id;
                               "peer", Cn_json.String peer_name] ();
                  print_endline (Cn_fmt.dim (Printf.sprintf "  Duplicate packet: %s" env.Cn_packet.msg_id));
                  None
              | Cn_packet.Equivocation ->
                  Cn_trace.gemit ~component:"mail" ~layer:Body
                    ~event:"packet.equivocation" ~severity:Warn ~status:Degraded
                    ~reason_code:"equivocation"
                    ~details:["msg_id", Cn_json.String env.Cn_packet.msg_id;
                               "peer", Cn_json.String peer_name;
                               "payload_sha256", Cn_json.String payload_sha] ();
                  print_endline (Cn_fmt.fail (Printf.sprintf "EQUIVOCATION: %s from %s (different content, same msg_id)" env.Cn_packet.msg_id peer_name));
                  let entry = Cn_packet.{ dedup_msg_id = env.msg_id; dedup_sender = env.pkt_sender;
                                          dedup_payload_sha = payload_sha; dedup_status = Equivocation } in
                  Cn_packet.save_dedup_index index_path (entry :: index);
                  None
              | Cn_packet.Rejected_dedup ->
                  Cn_trace.gemit ~component:"mail" ~layer:Body
                    ~event:"packet.rejected" ~severity:Warn ~status:Degraded
                    ~reason_code:"rejected_dedup"
                    ~details:["msg_id", Cn_json.String env.Cn_packet.msg_id;
                               "peer", Cn_json.String peer_name] ();
                  print_endline (Cn_fmt.fail (Printf.sprintf "Packet rejected (dedup): %s" env.Cn_packet.msg_id));
                  None
              | Cn_packet.Accepted ->
                  (* Materialize exact validated payload bytes *)
                  let topic_slug = Cn_hub.slugify env.Cn_packet.pkt_topic in
                  let inbox_file = Cn_hub.make_thread_filename (Printf.sprintf "%s-%s" peer_name topic_slug) in
                  let inbox_path = Cn_ffi.Path.join inbox_dir inbox_file in
                  let meta = [("state", "received"); ("from", peer_name);
                              ("msg_id", env.Cn_packet.msg_id);
                              ("trigger", env.Cn_packet.payload_sha256);
                              ("topic", env.Cn_packet.pkt_topic);
                              ("received", Cn_fmt.now_iso ())] in
                  Cn_ffi.Fs.write inbox_path (update_frontmatter content meta);
                  Cn_hub.log_action hub_path "packet.materialize"
                    (Printf.sprintf "%s msg_id:%s sha256:%s" inbox_file env.Cn_packet.msg_id payload_sha);
                  Cn_trace.gemit ~component:"mail" ~layer:Body
                    ~event:"packet.materialized" ~severity:Info ~status:Ok_
                    ~details:["msg_id", Cn_json.String env.Cn_packet.msg_id;
                               "peer", Cn_json.String peer_name;
                               "inbox_file", Cn_json.String inbox_file;
                               "payload_sha256", Cn_json.String payload_sha] ();
                  (* Update dedup index *)
                  let entry = Cn_packet.{ dedup_msg_id = env.msg_id; dedup_sender = env.pkt_sender;
                                          dedup_payload_sha = payload_sha; dedup_status = Accepted } in
                  Cn_packet.save_dedup_index index_path (entry :: index);
                  Some inbox_file

let inbox_process hub_path =
  print_endline (Cn_fmt.info "Processing inbox...");
  let inbox_dir = Cn_hub.threads_mail_inbox hub_path in
  Cn_ffi.Fs.ensure_dir inbox_dir;
  Cn_ffi.Fs.ensure_dir (Cn_ffi.Path.join hub_path "state");

  let my_name = derive_name hub_path in
  let peers = Cn_hub.load_peers hub_path in
  let materialized = peers |> List.fold_left (fun acc peer ->
    match peer.kind, peer.clone with
    | Some "template", _ -> acc
    | _, None -> acc
    | _, Some clone_path ->
        if not (Cn_ffi.Fs.exists clone_path) then acc
        else begin
          (* Fetch all refs including packet namespace *)
          let _ = Cn_ffi.Child_process.exec_in ~cwd:clone_path "git fetch origin --prune" in
          let _ = Cn_ffi.Child_process.exec_in ~cwd:clone_path
            (Printf.sprintf "git fetch origin '+refs/cn/msg/%s/*:refs/remotes/origin/cn/msg/%s/*' 2>/dev/null"
              peer.name peer.name) in

          (* Process packet refs — the only materialization path (#150).
             Legacy diff-based branches are no longer processed. *)
          let packet_refs = Cn_packet.list_packet_refs ~cwd:clone_path ~sender:peer.name in
          let packet_files = packet_refs |> List.filter_map (fun ref_name ->
            materialize_packet ~clone_path ~hub_path ~inbox_dir
              ~local_name:my_name ~peer_name:peer.name ref_name) in

          acc @ packet_files
        end
  ) [] in

  materialized |> List.iter (fun f -> print_endline (Cn_fmt.ok (Printf.sprintf "Materialized: %s" f)));
  match materialized with
  | [] -> print_endline (Cn_fmt.info "No new threads to materialize")
  | fs -> print_endline (Cn_fmt.ok (Printf.sprintf "Processed %d thread(s)" (List.length fs)))

(* === Outbox Operations === *)

let outbox_check hub_path =
  let outbox_dir = Cn_hub.threads_mail_outbox hub_path in
  match Cn_ffi.Fs.exists outbox_dir with
  | false -> print_endline (Cn_fmt.ok "Outbox clear")
  | true ->
      match Cn_ffi.Fs.readdir outbox_dir |> List.filter Cn_hub.is_md_file with
      | [] -> print_endline (Cn_fmt.ok "Outbox clear")
      | ts ->
          print_endline (Cn_fmt.warn (Printf.sprintf "%d pending send(s):" (List.length ts)));
          ts |> List.iter (fun f ->
            let content = Cn_ffi.Fs.read (Cn_ffi.Path.join outbox_dir f) in
            let meta = parse_frontmatter content in
            let to_peer = meta |> List.find_map (fun (k, v) -> if k = "to" then Some v else None)
              |> Option.value ~default:"(no recipient)" in
            print_endline (Printf.sprintf "  → %s: %s" to_peer f))

let send_thread hub_path name peers outbox_dir sent_dir file =
  let file_path = Cn_ffi.Path.join outbox_dir file in
  let content = Cn_ffi.Fs.read file_path in
  let meta = parse_frontmatter content in

  let to_peer = meta |> List.find_map (fun (k, v) -> if k = "to" then Some v else None) in

  match to_peer with
  | None ->
      Cn_trace.gemit ~component:"mail" ~layer:Body
        ~event:"outbox.skip" ~severity:Warn ~status:Degraded
        ~reason_code:"no_recipient"
        ~details:[
          "thread", Cn_json.String file;
        ] ();
      print_endline (Cn_fmt.warn (Printf.sprintf "Skipping %s: no 'to:' in frontmatter" file));
      None
  | Some to_name ->
      (* Self-send guard: prevent outbox flush when to == my_name (#144) *)
      if to_name = name then begin
        Cn_trace.gemit ~component:"mail" ~layer:Body
          ~event:"outbox.skip" ~severity:Warn ~status:Degraded
          ~reason_code:"self_send"
          ~details:[
            "thread", Cn_json.String file;
            "peer", Cn_json.String to_name;
          ] ();
        print_endline (Cn_fmt.warn (Printf.sprintf "Skipping %s: self-send (to=%s)" file to_name));
        None
      end else
      let peer = peers |> List.find_opt (fun p -> p.name = to_name) in
      match peer with
      | None ->
          Cn_trace.gemit ~component:"mail" ~layer:Body
            ~event:"outbox.skip" ~severity:Warn ~status:Degraded
            ~reason_code:"unknown_peer"
            ~details:[
              "thread", Cn_json.String file;
              "peer", Cn_json.String to_name;
            ] ();
          print_endline (Cn_fmt.fail (Printf.sprintf "Unknown peer: %s" to_name));
          None
      | Some _peer_info ->
          let ( let* ) = Result.bind in

          let thread_name = Cn_ffi.Path.basename_ext file ".md" in

          if !(Cn_fmt.dry_run_mode) then begin
            print_endline (Cn_fmt.dim (Printf.sprintf "Would: send %s to %s (packet)" file to_name));
            Some file
          end else

          (* Phase 1 (#150): send as canonical packet via refs/cn/msg/ namespace.
             Packet commits are root commits containing only packet/envelope.json
             and packet/message.md — no branch checkout needed. *)
          let msg_id = Cn_packet.make_msg_id name in
          let created_at = Cn_fmt.now_iso () in

          let send_result =
            let* s = Cn_protocol.sender_transition Cn_protocol.S_Pending Cn_protocol.SE_CreateBranch in
            let* (env, refname) = Cn_packet.create_git_packet
              ~cwd:hub_path ~sender:name ~recipient:to_name
              ~topic:thread_name ~content ~msg_id ~created_at
              |> Result.map_error (fun e -> e.Cn_packet.reason) in

            (* Push packet ref + verify *)
            let* s = Cn_protocol.sender_transition s Cn_protocol.SE_Push in
            let push_exit_ok = Cn_ffi.Child_process.exec_in ~cwd:hub_path
              (Printf.sprintf "git push origin %s -f" (Filename.quote refname))
              |> Option.is_some in
            let push_verified = push_exit_ok &&
              (Cn_ffi.Child_process.exec_in ~cwd:hub_path
                (Printf.sprintf "git ls-remote origin %s" (Filename.quote refname))
               |> Option.map (fun s -> String.length (String.trim s) > 0)
               |> Option.value ~default:false) in
            let* s = Cn_protocol.sender_transition s
              (if push_verified then Cn_protocol.SE_PushOk else Cn_protocol.SE_PushFail) in

            (* Cleanup: move to sent if pushed *)
            match s with
            | Cn_protocol.S_Pushed ->
                Cn_trace.gemit ~component:"mail" ~layer:Body
                  ~event:"packet.sent" ~severity:Info ~status:Ok_
                  ~details:[
                    "msg_id", Cn_json.String msg_id;
                    "sender", Cn_json.String name;
                    "recipient", Cn_json.String to_name;
                    "topic", Cn_json.String thread_name;
                    "payload_sha256", Cn_json.String env.Cn_packet.payload_sha256;
                    "ref", Cn_json.String refname;
                  ] ();
                Cn_ffi.Fs.write (Cn_ffi.Path.join sent_dir file)
                  (update_frontmatter content [
                    ("state", "sent"); ("sent", created_at);
                    ("msg_id", msg_id); ("payload_sha256", env.Cn_packet.payload_sha256)]);
                Cn_ffi.Fs.unlink file_path;
                let* s = Cn_protocol.sender_transition s Cn_protocol.SE_Cleanup in
                Ok (s, Some file)
            | _ ->
                Ok (s, None)
          in
          (match send_result with
           | Ok (s, result) ->
               let state_str = Cn_protocol.string_of_sender_state s in
               (match result with
                | Some _ ->
                    Cn_hub.log_action hub_path "outbox.send"
                      (Printf.sprintf "to:%s thread:%s msg_id:%s state:%s" to_name file msg_id state_str);
                    print_endline (Cn_fmt.ok (Printf.sprintf "Sent to %s: %s [%s]" to_name file msg_id))
                | None ->
                    Cn_hub.log_action hub_path "outbox.send"
                      (Printf.sprintf "to:%s thread:%s state:%s" to_name file state_str);
                    print_endline (Cn_fmt.fail (Printf.sprintf "Send failed for %s (state: %s)" file state_str)));
               result
           | Error e ->
               print_endline (Cn_fmt.fail (Printf.sprintf "Sender FSM: %s" e));
               None)

let outbox_flush hub_path name =
  let outbox_dir = Cn_hub.threads_mail_outbox hub_path in
  let sent_dir = Cn_hub.threads_mail_sent hub_path in

  if not (Cn_ffi.Fs.exists outbox_dir) then print_endline (Cn_fmt.ok "Outbox clear")
  else begin
    Cn_ffi.Fs.ensure_dir sent_dir;
    let threads = Cn_ffi.Fs.readdir outbox_dir |> List.filter Cn_hub.is_md_file in
    match threads with
    | [] -> print_endline (Cn_fmt.ok "Outbox clear")
    | ts ->
        print_endline (Cn_fmt.info (Printf.sprintf "Flushing %d thread(s)..." (List.length ts)));
        let peers = Cn_hub.load_peers hub_path in
        let _ = ts |> List.filter_map (send_thread hub_path name peers outbox_dir sent_dir) in
        print_endline (Cn_fmt.ok "Outbox flush complete")
  end

(* === Next Inbox Item === *)

let get_next_inbox_item hub_path =
  let inbox_dir = Cn_hub.threads_mail_inbox hub_path in
  if not (Cn_ffi.Fs.exists inbox_dir) then None
  else
    Cn_ffi.Fs.readdir inbox_dir
    |> List.filter Cn_hub.is_md_file
    |> List.sort String.compare
    |> function
      | [] -> None
      | file :: _ ->
          let file_path = Cn_ffi.Path.join inbox_dir file in
          let content = Cn_ffi.Fs.read file_path in
          let meta = parse_frontmatter content in
          let from = meta |> List.find_map (fun (k, v) -> if k = "from" then Some v else None)
            |> Option.value ~default:"unknown" in
          Some (Cn_ffi.Path.basename_ext file ".md", "inbox", from, content)

let run_next hub_path =
  match get_next_inbox_item hub_path with
  | None -> print_endline "(inbox empty)"
  | Some (id, cadence, from, content) ->
      Printf.printf "[cadence: %s]\n[from: %s]\n[id: %s]\n\n%s\n" cadence from id content

(* === Inbox Flush === *)

let inbox_flush hub_path _name =
  print_endline (Cn_fmt.info "Flushing inbox (deleting processed branches)...");
  let inbox_dir = Cn_hub.threads_mail_inbox hub_path in

  if not (Cn_ffi.Fs.exists inbox_dir) then begin
    print_endline (Cn_fmt.ok "Inbox empty");
    ()
  end else begin
    let threads = Cn_ffi.Fs.readdir inbox_dir |> List.filter Cn_hub.is_md_file in

    let flushed = threads |> List.filter_map (fun file ->
      let file_path = Cn_ffi.Path.join inbox_dir file in
      let content = Cn_ffi.Fs.read file_path in
      let meta = parse_frontmatter content in

      let is_triaged =
        List.exists (fun (k, _) -> k = "reply" || k = "completed" || k = "deleted" || k = "deferred") meta in

      if not is_triaged then None
      else begin
        match List.find_map (fun (k, v) -> if k = "branch" then Some v else None) meta with
        | None -> None
        | Some _branch ->
            (* Don't delete sender's branch — only sender deletes their own branches *)
            let archived_dir = Cn_ffi.Path.join hub_path "threads/archived" in
            Cn_ffi.Fs.ensure_dir archived_dir;
            Cn_ffi.Fs.write (Cn_ffi.Path.join archived_dir file)
              (update_frontmatter content [("flushed", Cn_fmt.now_iso ())]);
            Cn_ffi.Fs.unlink file_path;

            Cn_hub.log_action hub_path "inbox.flush" (Printf.sprintf "file:%s" file);
            print_endline (Cn_fmt.ok (Printf.sprintf "Flushed: %s" file));
            Some file
      end
    ) in

    match flushed with
    | [] -> print_endline (Cn_fmt.info "No triaged threads to flush")
    | fs -> print_endline (Cn_fmt.ok (Printf.sprintf "Flushed %d thread(s)" (List.length fs)))
  end
