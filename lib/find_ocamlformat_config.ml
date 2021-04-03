open! Import

(* Extracted from OCamlformat's [lib/Conf.ml]. *)

let local =
  let project_root_witnesses = [ ".git"; ".hg"; "dune-project" ] in
  let ( / ) = Fpath.( / ) in
  let rec scan_upwards curr =
    let here = curr / ".ocamlformat" in
    match Fpath.exists here with
    | true -> Some here
    | false -> (
        match
          List.exists project_root_witnesses ~f:(fun x ->
              Fpath.exists (curr / x))
        with
        | true -> None
        | false ->
            let parent = Fpath.parent curr in
            if parent == curr then None else scan_upwards parent)
  in
  fun ~from -> scan_upwards from

let global () =
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
