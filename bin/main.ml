open Cmdliner


(* Argument definition *)
let port_arg = Arg.(value & opt int 8080 & info ["p"; "port"] ~docv:"PORT" ~doc:"Port to listen on")
let host_arg = Arg.(value & opt string "localhost" & info ["h"; "host"] ~docv:"HOST" ~doc:"Host to listen on")


let server' port_arg host_arg = Printf.printf "Spawning server on %s:%d\n" host_arg port_arg
let server : unit Cmd.t =
  let info = Cmd.info "server" in
  Cmd.v info Term.(const server' $ port_arg $ host_arg)

let client' port_arg host_arg = Printf.printf "Connecting to %s:%d\n" host_arg port_arg
let client : unit Cmd.t =
  let info = Cmd.info "client" in
  Cmd.v info Term.(const client' $ port_arg $ host_arg)

let cmd : unit Cmd.t =
  let doc = "Yet another Chat Server" in
  let info = Cmd.info "yacht" ~version:"%%VERSION%%" ~doc in
  Cmd.group info [ server ; client]

let () = exit (Cmd.eval cmd)
