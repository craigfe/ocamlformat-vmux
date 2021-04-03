open! Import

let ( / ) = Filename.concat
let parent_loc = Xdg.config_dir / "ocamlformat-vmux"
let location = parent_loc / "config"

let read () =
  let sexp = Sexp.load_sexp location in

  match sexp with
  | List (Atom "versions" :: xs) ->
      List.fold_left xs ~init:String.Map.empty ~f:(fun m -> function
        | Sexp.List [ Atom version; Atom path ] ->
            String.Map.add version (Fpath.v path) m
        | x -> Fmt.failwith "Invalid version specification: %a" Sexp.pp x)
  | x -> Fmt.failwith "Invalid `versions` stanza: %a" Sexp.pp x

let write_diff m =
  let absent : bool =
    Bos.OS.Dir.create (Fpath.v parent_loc) |> Rresult.R.failwith_error_msg
  in
  let initial = if absent then String.Map.empty else read () in
  let to_write = String.Map.union (fun _ _ new_ -> Some new_) initial m in
  let versions =
    String.Map.bindings to_write
    |> List.map ~f:(fun (v, p) ->
           Sexp.List [ Atom v; Atom (Fpath.to_string p) ])
  in
  let sexp = Sexp.List (Atom "versions" :: versions) in
  Sexp.save_hum location sexp
