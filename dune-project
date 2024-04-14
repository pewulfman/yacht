(lang dune 3.14)

(name yacht)

(generate_opam_files true)

(source
 (github pewulfman/yacht))

(authors "Pierre-Emmanuel Wulfman")

(maintainers "Pierre-Emmanuel Wulfman")

(license MIT)

(package
 (name yacht)
 (synopsis "Simple Chat Server and Client in OCaml")
 (description "Simple Chat Server and Client in OCaml")
 (depends
  ocaml
  dune
  containers
  cmdliner
  eio
  eio_main
  notty
  yojson
  ppx_deriving
  ppx_deriving_yojson
  ppx_inline_test)
 (tags
  (ocaml5 chat)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
