open Eio
module Msg = Common.Msg



let run_eio host port env : unit =
  let net = Stdenv.net env in
  let clock = Stdenv.clock env in
  let stdin = Stdenv.stdin env
  and stdout = Stdenv.stdout env in
  traceln "connecting to %s:%d" host port;
  Switch.run ~name:"client" @@ fun sw ->
    Net.with_tcp_connect ~host ~service:(string_of_int port) net
    @@ fun socket ->
      let () = Common.session ~sw ~username:"client" ~clock ~stdin ~stdout socket in
      Net.close socket

let run host port = Eio_main.run (run_eio host port)
