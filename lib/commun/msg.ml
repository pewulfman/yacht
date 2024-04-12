open Eio


type payload = {author:bytes;content:bytes; id:int} [@@deriving yojson, show]
type t = Ack of int | Data of payload | End [@@deriving yojson, show]


let parse flow =
  (* Define Eio parser *)
  let parse =
    let open Eio.Buf_read.Syntax in
    let* len = Buf_read.BE.uint16 in
    let+ data = Buf_read.take len in
    data
  in
  (* Parsing with possible exception *)
  try
    parse flow
    |> Yojson.Safe.from_string
    |> of_yojson
    |> Result.map_error (fun s -> `Parse_error s)
  with End_of_file ->
    Result.error `End_of_file

let write flow t =
  let json = to_yojson t in
  let data = Yojson.Safe.to_string json in
  let len = String.length data in
    Buf_write.BE.uint16 flow len;
    Buf_write.string flow data
