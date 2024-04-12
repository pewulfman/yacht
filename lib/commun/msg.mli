type payload = {author:bytes;content:bytes; id:int}
type t = Ack of int | Data of payload | End

val parse : (t, [> `End_of_file | `Parse_error of string ]) result Eio.Buf_read.parser
val write : Eio.Buf_write.t -> t -> unit

val pp : Format.formatter -> t -> unit
