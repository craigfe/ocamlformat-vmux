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

let versioned_ocamlformat = Printf.sprintf "ocamlformat-%s"

let steal ~into =
  let install_location ~version =
    Printf.sprintf "%s/%s" into (versioned_ocamlformat version)
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
          Fmt.failwith "Non-zero return status for `cp`: %a" OS.Cmd.pp_status n);

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
    let ic = open_in (Fpath.to_string file) in
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

let get_required_version path =
  let config =
    match Find_ocamlformat_config.local ~from:path with
    | Some x -> Some x
    | None -> Find_ocamlformat_config.global ()
  in
  Option.bind config (fun file ->
      read_version_from_ocamlformat_config file
      |> Option.map (fun x -> (x, file)))

let inferred_version ~from:path =
  match get_required_version path with
  | None ->
      Fmt.pr "None\t%t@."
        (constf
           Fmt.(styled `Faint)
           "(no local `.ocamlformat` file for %a or in $XDG_CONFIG_HOME)"
           Fpath.pp path)
  | Some (v, p) ->
      Fmt.pr "Some %S\t%t@." v
        (constf Fmt.(styled `Faint) "(from: `%a`)" Fpath.pp p)

let shim ~from =
  let available_versions = Config.read () in
  let selected_binary =
    match get_required_version from with
    | None -> snd (String.Map.get_max_binding available_versions)
    | Some (version, config_file) -> (
        match String.Map.find_opt version available_versions with
        | Some path -> path
        | None ->
            Logs.err (fun f ->
                f "@[<hov>%a@]" Fmt.text
                  (Fmt.str_styled
                     "OCamlformat seems to want version %s (read from file \
                      `%a`), but the binary `%a` isn't available.\n\n\
                      Either create this binary manually or install it in an \
                      opam switch and re-run `%a`."
                     version
                     Fmt.(styled `Cyan Fpath.pp)
                     config_file cyan
                     (versioned_ocamlformat version)
                     cyan "ocamlformat-vmux steal"));
            exit 1)
  in
  Unix.execv (Fpath.to_string selected_binary) Sys.argv
