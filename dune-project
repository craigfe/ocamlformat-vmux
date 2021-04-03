(lang dune 2.0)
(generate_opam_files true)

(source (github mirage/alcotest))
(license MIT)
(authors "Craig Ferguson <me@craigfe.io>")
(maintainers "Craig Ferguson <me@craigfe.io>")

(package
 (name ocamlformat-vmux)
 (synopsis "OCamlformat version multiplexer")
 (depends
  (ocaml (>= 4.08))
  (dune-private-libs (>= 2.6.0))
  astring
  bos
  fmt
  fpath
  logs
  opam-state
  re
  rresult
  sexplib))
