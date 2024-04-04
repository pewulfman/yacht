module Msg = Msg
module List = Containers.List
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

module Message = struct
  (* make authomaticaly generate a new id *)
  let id = ref 0

  type t = {
    id : int;
    author: string;
    content : string;
    received : bool;
  } [@@ deriving show]

  let make author content : t =
    id := !id + 1;
    let id = !id in
    { id; author; content; received=false}

end

module History = struct
  type t = Message.t list

  let add t msg = msg :: t
  let ack (t : t) id = List.map (fun (msg : Message.t) -> if msg.id = id then {msg with received = true} else msg) t

  let view ?(pos=0) (t :t) : image =
    let open I in
    let view_message ({author; content; received; _} : Message.t) : image =
      let text = Format.asprintf "%s say: %s" author content in
      let color = if received then A.green else A.black in
      I.string A.(bg color) text
    in
    let sub_list = List.drop pos t in
    List.fold_right (fun message acc -> acc <-> view_message message) sub_list I.empty

end

type event = [ `Message of Message.t | `Ack of int | `Term of term_event ] [@@deriving show]

let () = ignore pp_event
type model = {
  textInput : Text_input.t;
  messages : History.t;
  username : string;
  pos : int;
}

let initModel username : model = {
  textInput = Text_input.make "" ();
  messages = [];
  username;
  pos = 0;
}

let update writer (event : event) model =
  match event with
  | `Message msg ->
    let messages = History.add model.messages msg in
    ({model with messages}, Command.Noop)
  | `Ack id ->
    let messages = History.ack model.messages id in
    ({model with messages}, Command.Noop)
  | `Term (`Key (`Escape, _)) -> (model, Command.Quit)
  | `Term (`Key (`Arrow `Up, _)) ->
      let pos = model.pos + 1 in
      ({model with pos}, Command.Noop)
  | `Term (`Key (`Arrow `Down, _)) ->
      let pos = model.pos - 1 in
      let pos = if pos < 0 then 0 else pos in
      ({model with pos}, Command.Noop)
  | `Term (`Key (`Enter, [])) ->
    let text = Text_input.current_text model.textInput in
    let message = Message.make model.username text in
    let () = writer message in
    let messages = History.add model.messages message in
    let textInput = Text_input.set_text "" model.textInput in
    ({model with messages; textInput}, Command.Noop)
  | `Term event ->
    let textInput = Text_input.update model.textInput event in
    ({model with textInput}, Command.Noop)

let grid xxs = xxs |> List.map I.hcat |> I.vcat

let outline attr (w,h) =
  let chr x = I.uchar attr (Uchar.of_int x) 1 1
  and hbar  = I.uchar attr (Uchar.of_int 0x2500) (w - 2) 1
  and vbar  = I.uchar attr (Uchar.of_int 0x2502) 1 (h - 2) in
  let (a, b, c, d) = (chr 0x256d, chr 0x256e, chr 0x256f, chr 0x2570) in
  grid [ [a; hbar; b]; [vbar; I.void (w - 2) 1; vbar]; [d; hbar; c] ]

let view model (w,h) : image =
  let open I in
  let input_box =
    I.string A.empty "Type your message and press Enter to send it (Escape to quit) :" <->
    Text_input.view model.textInput
  in
  let input_box_h = I.height input_box in
  let history_backgroud = (outline A.(fg lightred ) (w,h-input_box_h)) in
  let history =
    let header = I.string A.empty "Messages history :" in
    let view = History.view model.messages ~pos:model.pos in
    let sized_view =
      let view_h = I.height view in
      let max_height = h - input_box_h - I.height header in
      let view = I.pad ~l:1 view in
      if view_h > max_height - 1 then I.vcrop (view_h - max_height + 1) 0 view
      else view
    in
    header <->
    sized_view
  in
  history </> history_backgroud <->
  input_box


let main_loop read clock ~update ~view initModel initAction t =
  let event_queue : event Eio.Stream.t = Eio.Stream.create 100 in
  let rec ui_loop (model,action) t () : unit =
    (* Create and refresh the screen *)
    Term.image t @@ view model (Term.size t);
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
        let msg : Msg.t = Msg.parse read in
        match msg with
          Ack id ->
            Eio.Stream.add event_queue (`Ack id)
        | Data {author; content; id} ->
            Eio.Stream.add event_queue (`Message {id;author;content; received=true})
        );
    read_loop ()
  in
  Eio.Fiber.all [
  (ui_loop (initModel,initAction) t);
  (term_event_loop t);
  read_loop
  ]



let start ?(username = "Toto#" ^ (string_of_int @@ Random.int 12345 )) ~sw:_ ~clock read ~writer () =
  let t = Term.create ~nosig:false () in
  let update = update writer in
  let () = main_loop read clock ~update ~view (initModel username) Command.Noop t in
  Term.release t

