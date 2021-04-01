let () =
  match Sys.argv with
  | [| _; "steal"; into |] -> Ocamlformat_vmux.steal ~into
  | [| _; "inferred_version" |] ->
      Ocamlformat_vmux.inferred_version (Sys.getcwd ())
  | _ ->
      Fmt.epr "usage: %s [ steal <installation-dir> | inferred_version ]@."
        Sys.argv.(0);
      exit 1
