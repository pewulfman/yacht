(lang dune 3.14)

(name ahref_exercise)

(generate_opam_files true)

(source
 (github pewulfman/ahref_exercise))

(authors "Pierre-Emmanuel Wulfman")

(maintainers "Pierre-Emmanuel Wulfman")

(license MIT)

(package
 (name ahref_exercise)
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
