open! Import

let () =
  Logs.set_reporter
    (Logs_fmt.reporter
       ~pp_header:
         (fun ppf -> function
           | App, _ -> Fmt.(styled `Green (const string "→ ")) ppf ()
           | Error, _ -> Fmt.(styled `Red (const string "Error: ")) ppf ()
           | _ -> ())
       ())

let cyan = Fmt.(styled `Cyan string)

let get_opam_installed_versions () =
  OpamGlobalState.with_ `Lock_none (fun global_state ->
      let ocamlformat_versions =
        OpamPackage.Name.of_string "ocamlformat"
        |> OpamGlobalState.installed_versions global_state
      in

      OpamPackage.Map.fold
        (fun p switches m ->
          let version = OpamPackage.Version.to_string (OpamPackage.version p) in
          match String.Map.find version m with
          | Some _ -> m
          | None ->
              let selected_switch = List.hd switches in
              let entry =
                ( OpamSwitch.to_string selected_switch
                , OpamSwitch.get_root global_state.OpamStateTypes.root
                    selected_switch )
              in
              String.Map.add version entry m)
        ocamlformat_versions String.Map.empty)

let steal ~into =
  let install_location ~version =
    Printf.sprintf "%s/ocamlformat-%s" into version
  in

  Logs.app (fun f ->
      f "Getting the currently-installed OCamlformat versions:\n");
  let ocamlformat_versions = get_opam_installed_versions () in

  String.Map.iter ocamlformat_versions ~f:(fun k (v, _) ->
      print "  - %s\t%t" k (constf Fmt.(styled `Faint) "(switch: %s)" v));

  print "";
  Logs.app (fun f -> f "Stealing these versions into `%a`\n" cyan into);

  String.Map.iter ocamlformat_versions ~f:(fun version (_, x) ->
      let target = install_location ~version in
      let source =
        Printf.sprintf "%s/bin/ocamlformat" (OpamFilename.Dir.to_string x)
      in
      let cp = Cmd.(v "cp" % source % target) in
      match OS.Cmd.(run_status cp) |> Rresult.R.failwith_error_msg with
      | `Exited 0 ->
          print "  %s  %t  %s" target (constf Fmt.(styled `Faint) "↦") source
      | n ->
          Fmt.failwith "Non-zero return status for `cp`: %a"
            Bos.OS.Cmd.pp_status n);

  print "";
  Logs.app (fun f -> f "Writing this state to `%a`" cyan Config.location);
  let stolen_installation =
    ocamlformat_versions
    |> String.Map.mapi (fun version _ -> Fpath.v (install_location ~version))
  in
  Config.write_diff stolen_installation;
  Logs.app (fun f -> f "Done!")

let read_version_from_ocamlformat_config =
  let re = Re.Pcre.re " *version *= *(.*) *$" |> Re.compile in
  fun file ->
    let ic = open_in file in
    try
      let rec aux () =
        let line = input_line ic in
        match Re.Group.get (Re.exec re line) 1 with
        | v -> Some v
        | exception Not_found -> aux ()
      in
      aux ()
    with End_of_file ->
      close_in ic;
      None

let find_local_config =
  let project_root_witnesses = [ ".git"; ".hg"; "dune-project" ] in
  let ( / ) = Filename.concat in
  let rec scan_upwards curr =
    let here = curr / ".ocamlformat" in
    match Sys.file_exists here with
    | true -> Some here
    | false -> (
        match
          List.exists project_root_witnesses ~f:(fun x ->
              Sys.file_exists (curr / x))
        with
        | true -> None
        | false -> scan_upwards (Filename.dirname curr))
  in
  fun path -> scan_upwards path

(* Taken from OCamlformat's [lib/Conf.ml]. *)
let find_global_config () =
  let xdg_config_home =
    match Sys.getenv_opt "XDG_CONFIG_HOME" with
    | None | Some "" -> (
        match Sys.getenv_opt "HOME" with
        | None | Some "" -> None
        | Some home -> Some Fpath.(v home / ".config"))
    | Some xdg_config_home -> Some (Fpath.v xdg_config_home)
  in
  match xdg_config_home with
  | Some xdg_config_home ->
      let filename = Fpath.(xdg_config_home / "ocamlformat") in
      if Fpath.exists filename then Some filename else None
  | None -> None

let get_required_version path =
  let config =
    match find_local_config path with
    | Some x -> Some x
    | None -> Option.map Fpath.to_string (find_global_config ())
  in
  Option.bind config (fun file ->
      Option.map
        (fun x -> (x, file))
        (read_version_from_ocamlformat_config file))

let inferred_version path =
  match get_required_version path with
  | None ->
      Fmt.pr "None\t%t@."
        (constf
           Fmt.(styled `Faint)
           "(no local `.ocamlformat` file for %s or in $XDG_CONFIG_HOME)" path)
  | Some (v, p) ->
      Fmt.pr "Some %S\t%t@." v (constf Fmt.(styled `Faint) "(from: `%s`)" p)

let shim () =
  let available_versions = Config.read () in
  let version =
    match get_required_version (Sys.getcwd ()) with
    | Some (version, file) ->
        (match String.Map.find_opt version available_versions with
        | None ->
            Logs.err (fun f ->
                f "@[<hov>%a@]" Fmt.text
                  (Fmt.str_styled
                     "OCamlformat seems to want version %s (read from file \
                      `%a`), but the binary `%a` isn't available.\n\n\
                      Either create this binary manually or install it in an \
                      opam switch and re-run `%a`."
                     version cyan file cyan ("ocamlformat-" ^ version) cyan
                     "ocamlformat-vmux steal"));
            exit 1
        | Some _ -> ());
        version
    | None -> fst (String.Map.get_max_binding available_versions)
  in
  let ocamlformat_binary = Printf.sprintf "ocamlformat-%s" version in
  Unix.execvp ocamlformat_binary Sys.argv
