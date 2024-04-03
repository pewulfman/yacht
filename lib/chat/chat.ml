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

let pp_term_event ppf = function
  | `End -> Format.fprintf ppf "End"
  | `Key (`Escape, []) -> Format.fprintf ppf "Key Escape"
  | `Key (`Enter, []) -> Format.fprintf ppf "Key Escape"
  | `Key _key -> Format.fprintf ppf "Key"
  | `Mouse _mouse -> Format.fprintf ppf "Mouse"
  | `Paste _paste -> Format.fprintf ppf "Paste"
  | `Resize (w,h) -> Format.fprintf ppf "Resize (%d,%d)" w h

type event = [ `Ingress of string | `Term of term_event ] [@@deriving show]

let () = ignore pp_event


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
    let open I in
    I.string A.empty t <|> I.string A.(bg lightblue) " "
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

let update writer (event : event) model =
  match event with
  | `Ingress line ->
    let messages = line :: model.messages in
    ({model with messages}, Command.Noop)
  | `Term (`Key (`Escape, _)) -> (model, Command.Quit)
  | `Term (`Key (`Enter, [])) ->
    let text = Text_input.current_text model.textInput in
    let () = writer text in
    let messages = text :: model.messages in
    let textInput = Text_input.set_text "" model.textInput in
    ({messages; textInput}, Command.Noop)
  | `Term event ->
    let textInput = Text_input.update model.textInput event in
    ({model with textInput}, Command.Noop)

let view model : image =
  let open I in
  I.string A.empty "Messages history :"
  <->
  List.fold_right (fun message acc -> acc <-> I.string A.empty message) model.messages I.empty
  <->
  I.string A.empty "Type your message and press Enter to send it (Escape to quit) :"
  <->
  Text_input.view model.textInput


let main_loop read clock ~update ~view initModel initAction t =
  let event_queue : event Eio.Stream.t = Eio.Stream.create 100 in
  let rec ui_loop (model,action) t () : unit =
    (* Create and refresh the screen *)
    Term.image t @@ view model;
    Eio.Fiber.yield ();
    match action with
    | Command.Quit -> ()
    | Command.Noop ->
      (* Wait for an event *)
      let event = Eio.Stream.take event_queue in
      (* Add debug information *)
      (* let model = {model with messages = Format.asprintf "Debug: event received: %a" pp_event event :: model.messages} in *)
      let next_step = update event model in
      ui_loop next_step t ()
  in
  let term_event_loop t () =
    let rec aux () =
      Eio.Fiber.yield();
      (* Timeout to release the thread if there is no event*)
      Eio.Fiber.first
      (fun () -> Eio.Time.sleep clock 0.01 )
      (
        fun () ->
        let event = Term.event t in
        Eio.Stream.add event_queue (`Term event)
      );
      aux ()
    in
    aux ()
  in
  let rec read_loop () =
    Eio.Fiber.yield();
    Eio.Fiber.first (
      fun () -> Eio.Time.sleep clock 0.01
    )( fun () ->
      let line = Eio.Buf_read.line read in
        Eio.Stream.add event_queue (`Ingress line)
        );
    read_loop ()
  in
  Eio.Fiber.all [
  (ui_loop (initModel,initAction) t);
  (term_event_loop t);
  read_loop
  ]



let start ~sw:_ ~clock read ~writer () =
  let t = Term.create ~nosig:false () in
  let update = update writer in
  let () = main_loop read clock ~update ~view initModel Command.Noop t in
  Term.release t

