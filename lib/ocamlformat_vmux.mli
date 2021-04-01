val shim : unit -> unit
(** [exec] the appropriate stolen [ocamlformat] binary, assuming it exists in
    the path. *)

val steal : into:string -> unit
(** Copy the opam-installed [ocamlformat] binaries into the given directory. *)

val inferred_version : string -> unit
(** Print the version OCamlformat seems to expect when run from the given path. *)
