(** cn_doctor.ml — Doctor command thin wrapper (#167).

    Adds package-command integrity checks (Cn_command.validate) on top
    of the existing system doctor in Cn_system.run_doctor. *)

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
