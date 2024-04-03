module Msg = Msg
open Notty
open Notty_unix

(* Type return by Term.event, not present in the lib *)
type term_event =
  [ `End
  | `Key of Unescape.key
  | `Mouse of Unescape.mouse
  | `Paste of Unescape.paste
  | `Resize of int * int]


(* The intent is for the update function to communicate with the main loop (i.e. exit the app or continue) *)
module Command = struct
  type t =
    | Noop
    | Quit
end

module Text_input = struct
  type t = string

  let make text () = text
  let current_text t = t
  let set_text text _t = text

  let update t (event : term_event) =
    match event with
    | `Key (`ASCII c, []) -> t ^ (String.make 1 c)
    | `Key (`Backspace, []) -> String.sub t 0 (String.length t - 1)
    | _ -> t

  let view t : image =
    I.string A.empty t
end

type message = {
  author: string;
  content : string;
  received : bool;
}

let _pp_message : Format.formatter -> message -> unit = fun ppf {author; content; received; _} ->
  if received then
    Format.fprintf ppf "%s : %s ✅" author content
  else
  Format.fprintf ppf "%s : %s" author content

type model = {
  textInput : Text_input.t;
  messages : string list;
}

let initModel : model = {
  textInput = Text_input.make "" ();
  messages = [];
}

let update (event : term_event) model =
  match event with
  | `Key (`Escape, []) -> (model, Command.Quit)
  | `Key (`Enter, []) ->
    let text = Text_input.current_text model.textInput in
    let messages = text :: model.messages in
    let textInput = Text_input.set_text "" model.textInput in
    ({messages; textInput}, Command.Noop)
  | _ ->
    let textInput = Text_input.update model.textInput event in
    ({model with textInput}, Command.Noop)

let view model : image =
  let open I in
  I.string A.empty "Enter your message"
  <->
  (Text_input.view model.textInput)

let main_loop ~update ~view initModel initAction t =
  let rec loop (model,action) t =
  match action with
  | Command.Quit -> ()
  | Command.Noop ->
    let img = view model in
    Term.image t img;
    let next_step = update (Term.event t) model in
    loop next_step t
  in loop (initModel,initAction) t


let start () =
  let t = Term.create () in
  main_loop ~update ~view initModel Command.Noop t

