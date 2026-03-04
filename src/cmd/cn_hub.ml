(** cn_hub.ml — Hub discovery, path constants, and shared utilities

    Hub detection, path helpers, peer loading, timestamped naming.
    Shared infrastructure used by all domain modules. *)

open Cn_lib

(* === Hub Detection === *)

let rec find_hub_path dir =
  match dir with
  | "/" -> None
  | _ ->
      let has_yaml = Cn_ffi.Fs.exists (Cn_ffi.Path.join dir ".cn/config.yaml") in
      let has_json = Cn_ffi.Fs.exists (Cn_ffi.Path.join dir ".cn/config.json") in
      let has_peers = Cn_ffi.Fs.exists (Cn_ffi.Path.join dir "state/peers.md") in
      match has_yaml || has_json || has_peers with
      | true -> Some dir
      | false -> find_hub_path (Cn_ffi.Path.dirname dir)

(* === Logging === *)

(** Structured log to logs/cn.log (JSON lines, append) + stderr.
    This is the generic observability pattern: every action that
    could fail silently gets a log_action call. The log file provides
    audit trail; stderr provides daemon/cron visibility.

    Format: {"ts":"<ISO>","action":"<dotted>","details":"<free-text>"}
    Errors in the logger itself are swallowed (logging must not crash). *)
let log_action hub_path action details =
  let ts = Cn_fmt.now_iso () in
  let escape_json s =
    let buf = Buffer.create (String.length s) in
    String.iter (fun c -> match c with
      | '"' -> Buffer.add_string buf "\\\""
      | '\\' -> Buffer.add_string buf "\\\\"
      | '\n' -> Buffer.add_string buf "\\n"
      | '\r' -> Buffer.add_string buf "\\r"
      | c -> Buffer.add_char buf c) s;
    Buffer.contents buf in
  let line = Printf.sprintf "{\"ts\":\"%s\",\"action\":\"%s\",\"details\":\"%s\"}\n"
    ts (escape_json action) (escape_json details) in
  (* Emit to stderr for daemon/cron visibility *)
  Printf.eprintf "[%s] %s %s\n%!" ts action details;
  (* Append to logs/cn.log *)
  let log_dir = Cn_ffi.Path.join hub_path "logs" in
  let log_path = Cn_ffi.Path.join log_dir "cn.log" in
  (try
     Cn_ffi.Fs.ensure_dir log_dir;
     Cn_ffi.Fs.append log_path line
   with _ -> ()  (* logger must not crash the process *))

(* === Peers === *)

let load_peers hub_path =
  let peers_path = Cn_ffi.Path.join hub_path "state/peers.md" in
  match Cn_ffi.Fs.exists peers_path with
  | true -> parse_peers_md (Cn_ffi.Fs.read peers_path)
  | false -> []

(* === String Helpers === *)

let slugify ?max_len s =
  let s = match max_len with
    | Some n when String.length s > n -> String.sub s 0 n
    | _ -> s
  in
  let s = String.lowercase_ascii s in
  let buf = Buffer.create (String.length s) in
  let _last_was_sep =
    String.fold_left (fun was_sep c ->
      if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') then begin
        Buffer.add_char buf c; false
      end else if not was_sep then begin
        Buffer.add_char buf '-'; true
      end else was_sep
    ) true s
  in
  let result = Buffer.contents buf in
  let len = String.length result in
  if len > 0 && result.[len-1] = '-' then String.sub result 0 (len-1)
  else result

let sanitize_timestamp s =
  String.map (fun c -> if c = ':' || c = '.' then '-' else c) s

let remove_char c s =
  String.split_on_char c s |> String.concat ""

(* === Helpers === *)

let is_md_file = ends_with ~suffix:".md"
let split_lines s = String.split_on_char '\n' s |> List.filter non_empty

(* === Path Constants (v2 structure) === *)

let threads_in hub = Cn_ffi.Path.join hub "threads/in"
let threads_mail_inbox hub = Cn_ffi.Path.join hub "threads/mail/inbox"
let threads_mail_outbox hub = Cn_ffi.Path.join hub "threads/mail/outbox"
let threads_mail_sent hub = Cn_ffi.Path.join hub "threads/mail/sent"
let threads_reflections_daily hub = Cn_ffi.Path.join hub "threads/reflections/daily"
let threads_reflections_weekly hub = Cn_ffi.Path.join hub "threads/reflections/weekly"
let threads_adhoc hub = Cn_ffi.Path.join hub "threads/adhoc"
let mca_dir hub = Cn_ffi.Path.join hub "state/mca"

(* === Timestamped Naming === *)

let timestamp_slug () =
  let iso = Cn_fmt.now_iso () in
  let date = Cn_fmt.date_of_iso iso |> remove_char '-' in
  let time = Cn_fmt.time_of_iso iso |> remove_char ':' in
  Printf.sprintf "%s-%s" date time

let make_thread_filename slug =
  Printf.sprintf "%s-%s.md" (timestamp_slug ()) slug
