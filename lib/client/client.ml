open Eio

let connet ~net host port sw: _ Net.stream_socket_ty Std.r =
  let host =
    if host = "localhost" then
      Net.Ipaddr.V4.loopback
    else Net.Ipaddr.of_raw host
  in
  Net.connect ~sw net (`Tcp (host, port))


let run_eio host port env : unit =
  let net = Stdenv.net env in
  Switch.run ~name:"client" @@ fun sw ->
    let flow = connet ~net host port sw in
    Eio.Flow.copy flow (Stdenv.stdout env)

let run host port = Eio_main.run (run_eio host port)
