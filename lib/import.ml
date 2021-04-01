include Sexplib
include Stdlib.StdLabels
include Astring
include Bos

module Fpath = struct
  include Fpath

  let exists p = to_string p |> Sys.file_exists
end

module String = struct
  include String

  module Map = struct
    include Map

    let iter ~f m = iter f m
  end
end

module Fmt = struct
  include Fmt

  let buf = Buffer.create 512
  let buf_ppf = Format.formatter_of_buffer buf

  let () =
    Fmt_tty.setup_std_outputs ();
    Fmt.set_style_renderer buf_ppf (Fmt.style_renderer Fmt.stdout)

  let str_styled : type a. (a, Format.formatter, unit, string) format4 -> a =
   fun fmt ->
    Format.kdprintf
      (fun theta ->
        theta buf_ppf;
        Format.pp_print_flush buf_ppf ();
        let s = Buffer.contents buf in
        Buffer.reset buf;
        s)
      fmt
end

let print fmt = Format.kdprintf (Format.printf "@[<v 1>%t@]@.") fmt

let constf f fmt =
  Format.kdprintf (fun theta ppf -> f (fun ppf () -> theta ppf) ppf ()) fmt
