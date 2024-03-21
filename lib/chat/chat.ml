module Msg = Msg

open Minttea

type model = unit

let init _model = Command.Enter_alt_screen

let update event model =
  match event with
  | Event.KeyDown Escape -> (model, Command.Quit)
  | _ -> (model, Command.Noop)

let view _model = "press <ESC> to quit"

let app = Minttea.app ~init ~update ~view ()
let initModel = ()
