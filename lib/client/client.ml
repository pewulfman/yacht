open Eio
module Msg = Chat.Msg





let session socket =
  Buf_write.with_flow socket @@ fun _write ->
  Chat.start ()


let run_eio host port env : unit =
  let net = Stdenv.net env in
  traceln "connecting to %s:%d" host port;
  Switch.run ~name:"client" @@ fun _sw ->
    Net.with_tcp_connect ~host ~service:(string_of_int port) net
    @@ session

let run host port = Eio_main.run (run_eio host port)
