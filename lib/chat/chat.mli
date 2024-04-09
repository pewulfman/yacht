module Message : sig
  type t =
  | Mine of {
    id : int;
    author: string;
    content : string;
    sent_at : float;
    ack_recv_at : float option;
  }
  | Others of {
    author: string;
    content: string;
  }
end

type term_event
type event = [ `Message of Message.t | `Ack of int | `Term of term_event ]

val start : ?username:string -> clock: _ Eio.Time.clock -> input_stream:event Eio.Stream.t -> output_stream:Message.t Eio.Stream.t -> unit -> unit
