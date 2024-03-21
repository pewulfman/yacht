open Eio

type typ =
  Ack
| Data
[@@deriving enum, show]

(* shut up unused error *)
let _ = max_typ + min_typ

type t = {
  typ : typ;
  data : string;
}
[@@deriving show]
let ack = { typ = Ack; data = "" }
let data data = { typ = Data; data }



let parse flow =
  let typ = Buf_read.uint8 flow in
  match typ_of_enum typ with
  | Some Ack -> { typ = Ack; data = "" }
  | Some Data ->
    let len = Buf_read.BE.uint16 flow in
    let data = Buf_read.take len flow in
    { typ = Data; data }
  | None -> failwith "Invalid message type"

let write flow { typ; data } =
  Buf_write.uint8 flow (typ_to_enum typ);
  match typ with
  | Ack -> ()
  | Data ->
    Buf_write.BE.uint16 flow (String.length data);
    Buf_write.string flow data

