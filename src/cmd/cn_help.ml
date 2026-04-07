(** cn_help.ml — Help text rendering with command discovery.

    Built-in commands come from the static `Cn_lib.help_text`. External
    commands (repo-local + package-provided) are discovered from the
    current hub when one is available. *)

let print_external_section ~hub_path =
  let cmds = Cn_command.discover ~hub_path in
  if cmds = [] then ()
  else begin
    print_endline "";
    print_endline "External commands:";
    cmds |> List.iter (fun (c : Cn_command.external_cmd) ->
      let label = Cn_command.source_label c.source in
      if c.summary = "" then
        Printf.printf "  cn %-16s  [%s]\n" c.name label
      else
        Printf.printf "  cn %-16s  [%s] %s\n" c.name label c.summary)
  end

(** Print the help text. If we are inside a hub, also list external
    commands grouped by source. *)
let run_help () =
  print_endline Cn_lib.help_text;
  match Cn_hub.discover (Cn_ffi.Process.cwd ()) with
  | None -> ()
  | Some placement ->
      print_external_section ~hub_path:placement.Cn_placement.hub_root
