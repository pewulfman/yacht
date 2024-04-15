open Cmdliner


(* Argument definition *)
let host_arg n = Arg.(required & pos n (some string) None & info [] ~docv:"HOST" ~doc:"Host to listen on")
let port_arg = Arg.(value & opt int 8080 & info ["p"; "port"] ~docv:"PORT" ~doc:"Port to listen on")

let username_arg =
  let anonymous = Format.sprintf "anonymous#%d" (Random.int 10000) in
  Arg.(value & opt string anonymous  & info ["u"; "username"] ~docv:"USERNAME" ~doc:"Username to use")

(* Subcommands *)
let server : unit Cmd.t =
  let info = Cmd.info "server" in
  Cmd.v info Term.(const Server.run $ port_arg $ username_arg)

let client : unit Cmd.t =
  let info = Cmd.info "client" in
  Cmd.v info Term.(const Client.run $ host_arg 0 $ port_arg $ username_arg)

(* Main command *)
let cmd : unit Cmd.t =
  let doc = "Yet another Chat Server" in
  let info = Cmd.info "yacht" ~version:"%%VERSION%%" ~doc in
  Cmd.group info [ server ; client ]

let () = exit (Cmd.eval cmd)
