module Msg = Msg
open Eio

let session ~sw:_ ~username ~clock ~stdin ~stdout socket : unit =
  let input_stream = Stream.create 100 in
  let output_stream = Stream.create 100 in
  let sender_stream = Stream.create 100 in
  let rec forward_chat_message () =
      let () = match Stream.take output_stream with
      | Chat.Message.Mine {id; author; content; _} ->
        let author = Bytes.of_string author in
        let content = Bytes.of_string content in
        let msg : Msg.t = Data {id; author; content} in
        let () = Stream.add sender_stream msg in
        ()
      | _ -> ()
      in
      forward_chat_message ()
  in
  let outgoing_writer () =
    let rec loop () =
      Buf_write.with_flow socket @@ fun socket ->
      let msg = Stream.take sender_stream in
      let () = Msg.write socket msg in
      loop ()
    in loop ()
  in
  let rec incoming_listener () =
    let read = Buf_read.of_flow ~max_size:max_int socket in
    match Msg.parse read with
    | Ok (Ack id) ->
      Eio.Stream.add input_stream (`Ack id);
      incoming_listener ()
    | Ok (Data {author; content; id}) ->
      let author = Bytes.to_string author in
      let content = Bytes.to_string content in
      Eio.Stream.add input_stream (`Message (Others {author;content} : Chat.Message.t));
      Eio.Stream.add sender_stream (Ack id);
      incoming_listener ()
    | Ok (End) ->
      traceln "ending com";
      ()
    | Error (`End_of_file) ->
      traceln "end of file";
      ()
    | Error (`Parse_error err) ->
      traceln "error: %s" err;
      ()
  in
  let chat () = Chat.start ~username ~clock ~stdin ~stdout ~input_stream ~output_stream () in
  let () = Fiber.any [
    chat;
    incoming_listener;
    outgoing_writer;
    forward_chat_message;
  ] in
  (* Send termination message *)
  Net.close socket;
  ()

