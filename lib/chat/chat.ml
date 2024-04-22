module List = Containers.List
open Notty
open Notty_eio


(* Type return by Term.event, not present in the lib *)
type term_event =
  [ `Key of Unescape.key
  | `Mouse of Unescape.mouse
  | `Paste of Unescape.paste
  | `Resize ]

let pp_term_event ppf = function
  | `End -> Format.fprintf ppf "End"
  | `Key (`Escape, []) -> Format.fprintf ppf "Key Escape"
  | `Key (`Enter, []) -> Format.fprintf ppf "Key Enter"
  | `Key _key -> Format.fprintf ppf "Key"
  | `Mouse _mouse -> Format.fprintf ppf "Mouse"
  | `Paste _paste -> Format.fprintf ppf "Paste"
  | `Resize -> Format.fprintf ppf "Resize"



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
  [@@ deriving show]

  let make clock author content : t =
    id := !id + 1;
    let id = !id in
    let sent_at = Eio.Time.now clock in
    Mine {id; author; content; sent_at; ack_recv_at=None}

end

module History = struct
  type t = Message.t list

  let add t msg = msg :: t
  let ack clock (t : t) id = List.map (fun (msg : Message.t) ->
    match msg with
    | Mine msg when msg.id = id
      -> Message.Mine {msg with ack_recv_at = Eio.Time.now clock |> Option.some}
    | _ -> msg
   ) t

  let view ?(pos=0) w (t :t) : image =
    let open I in
    let view_message mess =
      let text = match mess with
      | Message.Mine {id=_; author; content; sent_at; ack_recv_at} ->
        let text = Format.asprintf "%s say: %s" author content in
        (match ack_recv_at with
          | Some (recv_at) -> text ^ (Format.asprintf " || ack time : %a s" Format.pp_print_float (Float.sub recv_at sent_at))
          | None -> text)
      | Message.Others {author; content} -> Format.asprintf "%s say: %s" author content
      in
      let text_lines = List.sublists_of_len ~last:CCOption.return (w - 2) @@ List.of_seq @@ String.to_seq text in
      List.fold_left (fun acc line ->
        let line = String.of_seq @@ List.to_seq line in
        acc <-> I.string A.empty line) I.empty text_lines
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

let update clock output_stream (event : event) model =
  match event with
  | `Message msg ->
    let messages = History.add model.messages msg in
    ({model with messages}, Command.Noop)
  | `Ack id ->
    let messages = History.ack clock model.messages id in
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
    let message = Message.make clock model.username text in
    let () =
     Eio.Stream.add output_stream message in
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
    let view = History.view w model.messages ~pos:model.pos in
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


let main_loop event_stream ~update ~view initModel initAction t : unit =
  let rec ui_loop (model,action) t () : unit =
    (* Create and refresh the screen *)
    let () = Term.image t @@ view model (Term.size t) in
    match action with
    | Command.Quit -> ()
    | Command.Noop ->
      (* Wait for an event *)
      let event = Eio.Stream.take event_stream in
        (* let model = {model with messages = {id=0;author="debug";content=Format.asprintf "Debug: event received: %a" pp_event event;received=true} :: model.messages} in *)
      let next_step = update event model in
      ui_loop next_step t ()
  in
    ui_loop (initModel,initAction) t ()



let start ?(username = "Toto#" ^ (string_of_int @@ Random.int 12345 )) ~clock ~stdin ~stdout ~input_stream ~output_stream () : unit=
  let update = update clock output_stream in
  let event_stream = Eio.Stream.create 1 in
  let ui_loop t = main_loop event_stream ~update ~view (initModel username) Command.Noop t in
  let on_event event = Eio.Stream.add event_stream (`Term event) in
  let rec read_loop () : unit =
    let message = Eio.Stream.take input_stream in
    let () = Eio.Stream.add event_stream message in
    read_loop ()
  in
  Eio.Fiber.first read_loop
   @@ fun () -> Term.run ~input:stdin ~output:stdout ~on_event ui_loop
