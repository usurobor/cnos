(** cn_doctor.ml — Doctor command entry point.

    Runs the system doctor (Cn_system.run_doctor), then validates the
    external-command surface (Cn_command.validate), then validates the
    activation surface (Cn_activation.validate). Trigger conflicts are
    fail-stop (exit 1); other categories are warnings. *)

let report_commands ~hub_path =
  let discovered = Cn_command.discover ~hub_path in
  let issues = Cn_command.validate ~hub_path in
  match discovered, issues with
  | [], [] -> false
  | _ :: _, [] ->
      print_endline (Cn_fmt.ok
        (Printf.sprintf "Commands: %d healthy" (List.length discovered)));
      false
  | _, _ :: _ ->
      print_endline (Cn_fmt.warn "Commands:");
      issues |> List.iter (fun msg ->
        print_endline (Printf.sprintf "  %s" (Cn_fmt.warn msg)));
      true

let report_activation ~hub_path =
  let entries = Cn_activation.build_index ~hub_path in
  let issues  = Cn_activation.validate ~hub_path in
  let any_conflict = List.exists
    (fun (i : Cn_activation.issue) ->
       i.kind = Cn_activation.Trigger_conflict)
    issues
  in
  (match entries, issues with
   | [], [] -> ()
   | _ :: _, [] ->
       print_endline (Cn_fmt.ok
         (Printf.sprintf "Activation: %d skill(s) indexed"
            (List.length entries)))
   | _, _ ->
       print_endline (Cn_fmt.warn "Activation:");
       issues |> List.iter (fun (i : Cn_activation.issue) ->
         let line = Printf.sprintf "  [%s] %s"
           (Cn_activation.issue_kind_label i.kind) i.message in
         match i.kind with
         | Cn_activation.Trigger_conflict ->
             print_endline (Cn_fmt.fail line)
         | _ ->
             print_endline (Cn_fmt.warn line)));
  any_conflict

let run_doctor ~hub_path =
  Cn_system.run_doctor hub_path;
  let cmd_failed  = report_commands   ~hub_path in
  let act_failed  = report_activation ~hub_path in
  if cmd_failed || act_failed then
    Cn_ffi.Process.exit 1
