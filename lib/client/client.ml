open Eio
module Msg = Chat.Msg




(* let session ~stdin socket =
  let stdin = Buf_read.of_flow stdin ~max_size:1000 in
  let buf = Buf_read.of_flow ~max_size:max_int socket in
  let rec loop () =
    traceln "reading from stdin";
    let msg =  Buf_read.line stdin in
    traceln "sending: %s" msg;
    let () = Buf_write.with_flow socket @@ fun socket ->
      Buf_write.string socket (msg ^ "\n");
      Eio.Fiber.yield ()
    in
    traceln "reading from socket";
    let msg = Buf_read.line buf in
    traceln "received: %s" msg;
    loop ()
  in loop () *)


let session ~sw ~clock socket =
  let writer ({id; author; content; _} : Chat.Message.t) =
    let msg : Msg.t = Data {id; author; content} in
    let write_fiber = fun () ->
    Buf_write.with_flow socket @@ fun socket ->
      Msg.write socket msg
    in
    Eio.Fiber.fork ~sw write_fiber
  in
  let read = Buf_read.of_flow ~max_size:max_int socket in
  Chat.start ~username:"client" ~sw ~clock read ~writer ()


let run_eio host port env : unit =
  let net = Stdenv.net env in
  let clock = Stdenv.clock env in
  traceln "connecting to %s:%d" host port;
  Switch.run ~name:"client" @@ fun sw ->
    Net.with_tcp_connect ~host ~service:(string_of_int port) net
    @@ session ~sw ~clock

let run host port = Eio_main.run (run_eio host port)
