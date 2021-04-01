open! Import

val location : string
val write_diff : Fpath.t String.Map.t -> unit
val read : unit -> Fpath.t String.Map.t
