open Eio
module Msg = Common.Msg


let handle_connect ~sw ~clock : _ Net.connection_handler = fun socket stream ->
  Format.printf "Socket: %a\n" Net.Sockaddr.pp stream ;
  Format.print_flush();
  Common.session ~sw ~clock ~username:"server" socket


let listening_soket (host : string) (port : int) (net : _ Std.r) =
  (* TODO : host and port sanitation *)
  let host =
    if host = "localhost" then
      Net.Ipaddr.V4.loopback
    else Net.Ipaddr.of_raw host
  in
  Net.listen ~backlog:10
  net (`Tcp (host, port))

let run_eio host port env =
  let () = Printf.printf "Spawning server on %s:%d\n" host port in
  let net = Stdenv.net env in
  let clock = Stdenv.clock env in
  Switch.run ~name:"server" (fun sw ->
  Net.run_server ~max_connections:1 ~on_error:raise
    (listening_soket host port net ~sw)
    (handle_connect ~sw ~clock)
  )

let run host port =
  Eio_main.run (run_eio host port)
