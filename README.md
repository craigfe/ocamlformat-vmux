# OCamlformat version multiplexer

As of today, OCamlformat is normally consumed via installing the appropriate version into a dev switch. This is a bit painful, since the OCamlformat dependency tree is quite large and can conflict with other common dev switch inclusions (especially Odoc and Ppxlib).

This project provides an awful hack to get around this problem: install all the versions, and provide a shim `ocamlformat` binary that proxies to the appropriate one at runtime. With this shim in your `$PATH`, you can stop installing OCamlformat in Opam switches :tada:

## Usage

```bash
; opam pin add -n ocamlformat-vmux git+https://github.com/CraigFe/ocamlformat-vmux
; opam install ocamlformat-vmux

# Pull all installed OCamlformat versions into ~/.local/bin/
; ocamlformat-vmux steal ~/.local/bin

# Put the shim `ocamlformat` binary somewhere in your path
; ln -s "$(which ocamlformat-vmux-shim)" ~/.local/bin/ocamlformat

# Purge opam-installed `ocamlformat` from your life
; opam switch -s | xargs -n1 -I{} opam remove ocamlformat --switch={} --yes
```
