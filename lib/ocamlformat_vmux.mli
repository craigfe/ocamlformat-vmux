val steal : into:string -> unit
(** Copy the opam-installed [ocamlformat] binaries into the given directory. *)

val inferred_version : from:Fpath.t -> unit
(** Print the version OCamlformat seems to expect when run from the given path. *)

val shim : from:Fpath.t -> unit
(** [exec] the appropriate stolen [ocamlformat] binary, assuming it exists in
    the path. *)
