(** cn_doctor.ml — Doctor command entry point.

    Runs the system doctor (Cn_system.run_doctor) and then the
    external-command integrity checks from Cn_command.validate. *)

let run_doctor ~hub_path =
  Cn_system.run_doctor hub_path;
  let discovered = Cn_command.discover ~hub_path in
  let issues = Cn_command.validate ~hub_path in
  match discovered, issues with
  | [], [] -> ()  (* nothing to report *)
  | _ :: _, [] ->
      print_endline (Cn_fmt.ok
        (Printf.sprintf "Commands: %d healthy" (List.length discovered)))
  | _, _ :: _ ->
      print_endline (Cn_fmt.warn "Commands:");
      issues |> List.iter (fun msg ->
        print_endline (Printf.sprintf "  %s" (Cn_fmt.warn msg)));
      Cn_ffi.Process.exit 1
