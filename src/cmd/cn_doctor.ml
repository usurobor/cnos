(** cn_doctor.ml — Doctor command entry point.

    Runs the system doctor (Cn_system.run_doctor) and then the
    external-command integrity checks from Cn_command.validate. *)

let run_doctor ~hub_path =
  Cn_system.run_doctor hub_path;
  let issues = Cn_command.validate ~hub_path in
  if issues = [] then
    print_endline (Cn_fmt.ok "Commands: clean")
  else begin
    print_endline (Cn_fmt.warn "Commands:");
    issues |> List.iter (fun msg ->
      print_endline (Printf.sprintf "  %s" (Cn_fmt.warn msg)));
    Cn_ffi.Process.exit 1
  end
