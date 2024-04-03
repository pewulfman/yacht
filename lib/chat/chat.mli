module Msg = Msg
open Eio

type model

val start : sw:Switch.t -> clock:_ Time.clock -> Buf_read.t -> writer:(string -> unit) -> unit -> unit
