module Msg = Msg

open Minttea
open Leaves

type model = {
  textInput : Text_input.t;
  messages : string list;
}

let initModel : model = {
  textInput = Text_input.make "" ();
  messages = [];
}
let init _model = Command.Enter_alt_screen

let update event model =
  match event with
  | Event.KeyDown Escape -> (model, Command.Quit)
  | Event.KeyDown Enter ->
    let messages = Text_input.current_text model.textInput :: model.messages in
    let textInput = Text_input.set_text "" model.textInput in
    ({textInput; messages}, Command.Noop)
  | _ ->
    let textInput = Text_input.update model.textInput event in
    ({model with textInput}, Command.Noop)

let view model = Format.sprintf {|
Your friends are saying :
%s
What do you want to say today ?
%s
|}
  (String.concat "\n" @@ List.rev model.messages)
  (Text_input.view model.textInput)


let app = Minttea.app ~init ~update ~view ()
