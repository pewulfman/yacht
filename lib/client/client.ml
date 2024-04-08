open Eio
module Msg = Common.Msg




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


let session ~sw ~clock socket : unit =
  let input_stream = Stream.create 100 in
  let output_stream = Stream.create 100 in
  let sender_stream = Stream.create 100 in
  let rec forward_chat_message () =
      let {id; author; content; _} : Chat.Message.t = Stream.take output_stream in
      let author = Bytes.of_string author in
      let content = Bytes.of_string content in
      let msg : Msg.t = Data {id; author; content} in
      let () = Stream.add sender_stream msg in
      forward_chat_message ()
  in
  let outgoing_writer () =
    Buf_write.with_flow socket @@ fun socket ->
    let rec loop () =
      let msg = Stream.take sender_stream in
      let () = Msg.write socket msg in
      loop ()
    in loop ()
  in
  let read = Buf_read.of_flow ~max_size:max_int socket in
  let rec incoming_listener () =
    Eio.Fiber.first (
      fun () -> Eio.Time.sleep clock 0.01
    )( fun () ->
        let msg : Msg.t = Msg.parse read in
        match msg with
          Ack id ->
            Eio.Stream.add input_stream (`Ack id)
        | Data {author; content; id} ->
            let author = Bytes.to_string author in
            let content = Bytes.to_string content in
            Eio.Stream.add input_stream (`Message ({id;author;content; received=true} : Chat.Message.t));
            Eio.Stream.add sender_stream (Ack id)
        );
    incoming_listener ()
  in
  Fiber.fork_daemon ~sw incoming_listener;
  Fiber.fork_daemon ~sw outgoing_writer;
  Fiber.fork_daemon ~sw forward_chat_message;
  Chat.start ~username:"client" ~clock ~input_stream ~output_stream ()


let run_eio host port env : unit =
  let net = Stdenv.net env in
  let clock = Stdenv.clock env in
  traceln "connecting to %s:%d" host port;
  Switch.run ~name:"client" @@ fun sw ->
    Net.with_tcp_connect ~host ~service:(string_of_int port) net
    @@ session ~sw ~clock

let run host port = Eio_main.run (run_eio host port)
