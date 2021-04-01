(lang dune 2.0)
(generate_opam_files true)

(package
 (name ocamlformat-vmux)
 (depends logs fmt opam-state box rresult fpath re dune-private-libs sexplib))
