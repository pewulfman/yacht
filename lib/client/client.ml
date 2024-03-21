open Eio
module Msg = Chat.Msg



let session ~stdin ~stdout:_ socket =
  let stdin = Buf_read.of_flow stdin ~max_size:1000 in
  let buf = Buf_read.of_flow ~max_size:max_int socket in
  let rec loop () =
    traceln "reading from stdin";
    let msg =  Buf_read.line stdin in
    traceln "sending: %s" msg;
    let () = Buf_write.with_flow socket @@ fun socket ->
      Msg.write socket @@ Msg.data msg;
    in
    traceln "reading from socket";
    let msg = Msg.parse buf in
    traceln "received: %a" Msg.pp msg;
    loop ()
  in loop ()


let run_eio host port env : unit =
  let net = Stdenv.net env in
  let stdin = Stdenv.stdin env in
  traceln "connecting to %s:%d" host port;
  Switch.run ~name:"client" @@ fun _sw ->
    Net.with_tcp_connect ~host ~service:(string_of_int port) net
    @@ session ~stdin ~stdout:(Stdenv.stdout env)

let run host port = Eio_main.run (run_eio host port)
