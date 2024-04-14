open Eio
module Msg = Common.Msg


let handle_connect ~sw ~clock  ~stdin ~stdout : _ Net.connection_handler = fun socket stream ->
  Format.printf "Socket: %a\n" Net.Sockaddr.pp stream ;
  Format.print_flush();
  Common.session ~sw ~username:"server" ~clock ~stdin ~stdout socket


let listening_soket (port : int) (net : _ Std.r) =
  let host = Net.Ipaddr.V4.loopback in
  Net.listen ~backlog:10 net (`Tcp (host, port))

let run_eio port env =
  let () = Printf.printf "Spawning server on port %d\n" port in
  let net = Stdenv.net env in
  let clock = Stdenv.clock env in
  let stdin = Stdenv.stdin env
  and stdout = Stdenv.stdout env in
  Switch.run ~name:"server" (fun sw ->
    try
      Net.run_server ~max_connections:1 ~on_error:raise
        (listening_soket ~sw port net)
        (handle_connect ~sw ~clock ~stdin ~stdout)
      (* Shouldn't raise according to doc *)
    with
    | Invalid_argument s -> Printf.eprintf "Invalid argument: %s\n" s
    | Unix.Unix_error (Unix.EADDRINUSE, _, _) -> Printf.eprintf "Error: port %d already in use\n" port
    | Unix.Unix_error (_, _, _) as e -> Format.eprintf "Error: unknown Unix error %a\n" Exn.pp e
    | Common.(Exn (Parse_error e)) -> Printf.eprintf "Error while parsing incoming message: %s\n%!" e
    | Common.(Exn Terminated_by_Peer) -> Printf.eprintf "Connection terminated by peer\n%!"
  )

let run port =
  Eio_main.run (run_eio port)
