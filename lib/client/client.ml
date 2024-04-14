open Eio
module Msg = Common.Msg



let run_eio host port env : unit =
  let net = Stdenv.net env in
  let clock = Stdenv.clock env in
  let stdin = Stdenv.stdin env
  and stdout = Stdenv.stdout env in
  Switch.run ~name:"client" @@ fun sw ->
    try
      Net.with_tcp_connect ~host ~service:(string_of_int port) net
      @@ fun socket ->
        Common.session ~sw ~username:"client" ~clock ~stdin ~stdout socket
    with
      | Io (Net.E (Net.Connection_failure Timeout), _) -> Printf.eprintf "Connection timeout\n%!"
      | Io (Net.E (Net.Connection_failure No_matching_addresses), _) -> Printf.eprintf "No matching address\n%!"
      | Io (Net.E (Net.Connection_failure Refused e), _) -> Format.eprintf "Connection refused: %a\n%!" Exn.Backend.pp e
      | Io (Net.E (Net.Connection_reset e), _) -> Format.eprintf "Connection reset: %a\n%!" Exn.Backend.pp e
      | Common.(Exn (Parse_error e)) -> Printf.printf "Error while parsing incoming message: %s\n%!" e
      | Common.(Exn Terminated_by_Peer) -> Printf.printf "Connection terminated by peer\n%!"

let run host port = Eio_main.run (run_eio host port)
