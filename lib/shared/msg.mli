type t

val ack : t
val data : string -> t

val parse : t Eio.Buf_read.parser
val write : Eio.Buf_write.t -> t -> unit

val pp : Format.formatter -> t -> unit
