open Eio
module Msg = Common.Msg


let handle_connect : _ Net.connection_handler = fun socket stream ->
  print_endline "New connection";
  Format.printf "Socket: %a\n" Net.Sockaddr.pp stream ;
  Format.print_flush();
  let buf = Buf_read.of_flow ~max_size:max_int socket in
  let rec loop () =
    traceln "Waiting for message";
    let msg = Msg.parse buf in
    traceln "Got message : %a" Msg.pp msg;
    let id = match msg with Ack id | Data {id;_} -> id in
    let () = Buf_write.with_flow socket @@ fun write ->
      let ack = Msg.Ack (id) in
      traceln "Sending message : %a" Msg.pp ack ;
      Msg.write write ack;
    in
    traceln "Looping";
    loop () in
  loop ()


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
  Switch.run ~name:"server" (fun sw ->
  Net.run_server ~on_error:(fun e -> Printf.printf "Error: %s\n" (Printexc.to_string e))
    (listening_soket host port net ~sw)
    (handle_connect)
  )

let run host port =
  Eio_main.run (run_eio host port)
