open Eio

type payload = {author:string;content:string; id:int} [@@deriving yojson, show]
type t = Ack of int | Data of payload [@@deriving yojson, show]


let parse flow : t =
  let len = Buf_read.BE.uint16 flow in
  let data = Buf_read.take len flow in
  let json = Yojson.Safe.from_string data in
  of_yojson json |> Result.get_ok

let write flow t =
  let json = to_yojson t in
  let data = Yojson.Safe.to_string json in
  let len = String.length data in
    Buf_write.BE.uint16 flow len;
    Buf_write.string flow data

