type payload = {author:string;content:string; id:int}
type t = Ack of int | Data of payload

val parse : t Eio.Buf_read.parser
val write : Eio.Buf_write.t -> t -> unit

val pp : Format.formatter -> t -> unit
