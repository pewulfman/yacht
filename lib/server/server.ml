open Eio


let handle_connect : _ Net.connection_handler = fun socket stream ->
  print_endline "New connection";
  Format.printf "Socket: %a\n" Net.Sockaddr.pp stream ;
  Format.print_flush();
  Flow.copy_string "Hello, world!" socket;
  Flow.close socket


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
  Switch.run ( fun sw ->
  Net.run_server ~on_error:(fun e -> Printf.printf "Error: %s\n" (Printexc.to_string e))
    (listening_soket host port net ~sw)
    (handle_connect)
  )

let run host port =
  Eio_main.run (run_eio host port)
