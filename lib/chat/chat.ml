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

  let view t = t
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
  I.string A.empty @@
  Format.asprintf {|
Your friends are saying :
%a
What do you want to say today ?
%s
|}
  (Format.pp_print_list ~pp_sep:(Format.pp_print_newline) Format.pp_print_string ) model.messages
  (Text_input.view model.textInput)

let main_loop t ~init ~(update: term_event -> model -> model * Command.t) ~view ()  =
  Eio.traceln "Starting the main loop";
  Eio.traceln "Term created";
  let rec loop model =
    Eio.traceln "Looping";
    let img = view model in
    Term.image t img;
    match Term.event t with
    | `End -> ()
    | event ->
      let model, command = update event model in
      match command with
      | Command.Quit -> ()
      | Command.Noop -> loop model
  in
  loop init



let start () =
  Eio.traceln "Starting the app";
  let t = Term.create () in
  main_loop t ~init:initModel ~update ~view ()

