# Getting things Done

From the specifications, I decide to split the software into 3 main components:

1. A CLI to launch the software in the correct mode
1. A network layer
1. A graphical UI interface

So after initializing a new project with dune. I start working on these parts.

## Part 1. Building the CLI (CmdLiner)

When working at LigoLang, I ended up redesign the CLI and porting `CmdLiner` to JaneStreet's `Command`. Thus, I have plenty of experience, and it went straight forward.

I chose to use `CmdLiner` as you don't need to install the whole `Core` library, which I don't need.

For this part, I simply filled the `main.ml` file of the bin folder with the command definition. Calling 2 new lib `client` and `server`.

For simplicity during dev, host is default to localhost and port to 8080

## Part 2. Simple web communication (Eio)

I came across `Lwt` code before, but never actually used it. Since I like to use cutting edge tech or experimental tech in my side-project,
it made sense to me to use the new OCaml-multicore library `Eio`.

Nothing specific to say here. It was very easy to set up a simple server and TCP connection, and after playing around with `Flow`, to find out how to use `Buf_read` and `Buf_write`.

On the client, I codded a simple loop that listens to stdin, sends a message to the server and waits for the server to send back an acknowledgement. On the server, I just display the received message to check.
(I also made a primitive message lib but not very relevant at this point).

While I only really communicate in one direction, my goal was to validate that I am able to transmit message, and it was met. I just wanted to make a chat app that would be use by both the client and server, so I went on with it.

## Part 3. User interface (Minttea)

Then came the interesting part, as I never made a GUI in OCaml before. My experience with GUI are web interface (`Rescript-react`) and one `C` and one `Java` application during university, 10 years ago, so things have change since then.

I went on to search for graphic libraries for OCaml, I could either use a `GUI`, or one of a few `TUI` and I never did an app in a terminal before, so I chose the later option. Also since the specification cares about the front-end, the simpler, the better. (I even considered using a file open with `less` to display the message history but let's be serious)

I found out the `Minttea` lib that first, has a cool name, and that's important. And second used the `ELM` architecture, very familiar to a React programmer like me, and I was able to make the equivalent of the grocery list app, i.e. a text field and a list of all the previous input.

Great now, I needed to connect the chat with the network socket and that should work.

## Part 4. Connecting people

So intuitively, I assumed that if I extend my chat with an input pipe and output pipe and add in the message list what I get from the input pipe and write on the output pipe, I should be more or less done.

I did several attempts with this idea, adding the pipe in the model or as a parameter of the update closure, but the message got transmitted only when I close the application which to me means that I don't let the scheduler release the chat threads and run the communication thread.
So I tried to yield the chat thread which did send the message but also triggered an exception `Suspend` from `Eio` and I couldn't find why and how to prevent it.

Looking further into the implementation of `Minttea`, it uses the `Riot` lib for handling the thread. My understanding is that when running the chat app, I run a new "`Riot` scheduler" and when I try to `yield` my `Eio` fiber, it goes through the "`Riot` scheduler" then the "`Eio scheduler`" and when going back to fiber with "`Riot` scheduler" there is some interference somewhere. With not a better understanding of the issue and no result from my web searches, I decided that I should not try to integrate `Minttea` and `Eio` anymore. So I can either replace `Eio` with `Riot` and use their net library, but I really wanted to use `Eio`, and I am pretty happy with it. Or use another front-end library which would also provide me experience with a more popular UI lib, so this is the option I chose.

## Part 3 again. User interface (Notty)

This part was actually quite straightforward. I reimplemented the main loop and ended up with a similar API, so I could reuse what I did. I ended up with an ELM architecture, but now the UI thread is handled by the same scheduler as the rest of the app.

## Part 4 again. Connecting the thing

With now full control over my fiber poll, I was able to create different threads for the display and the communication. The only issue that I have is that the `Term.event` from `Notty` which listen to user event is blocking which lead to different issue.
I was able to get almost everything to work, the only weird behavior is that once I send a message, the acknowledgement will only appear after a new term event... This doesn't impact functionality per se but definitely damage user experience, so I want to fix it at some point. I have several ideas to try but right now I would rather focus on improving the UI.

## Part 5. Implement the message protocol

Now that I have something working somewhat, sending a simple string and receiving a simple string, let's make the chat a custom protocol.
We already somewhat did it in part 2, so that should be quite straightforward.

I improved my message serialization leveraging `yojson` and I obtained what I wanted: messages turns green after being acknowledge.

Still have the same weird blocking of the screen from the `Notty` term, as expected.

## Part 6. Make a nicer interface

Taking inspiration from [https://github.com/cedlemo/OCaml-Notty-introduction?tab=readme-ov-file#the-unix-term-module](), I made it so the input is always at the bottom and the center view with the chat history is contained and scrollable.
The current implementation is incomplete as I don't handle the user scrolling too far up the history (line disappears instead of cursor being blocked, and reappears when scrolling in the other direction) but this is good enough given the objective of this task, I may work on that later.

## Part 7. Refactor chat and threads

The current architecture was made "as it goes" to just test and iterate fast until I get enough experience with the libraries to fix the implementation. Now it's time to make a proper interface.

Ideally the chat should take an input stream of incoming messages and acknowledgements and an output stream of outgoing messages.
I added an optional username that is generated if not provided (the generation is trivial because it's out of scope)

I use `_ Eio.Steam.t` for the stream. The issue with this is that it makes the chat interface bounded to the `Eio` lib. This could be an issue if we want to reuse the chat for a project that would use another library than `Eio` for multithreading. I considered another design which, instead of streams would take a reader and a writer closure (`() -> event`, `Message.t -> ()`). This interface doesn't require the user to use `Eio`, but it felt over-engineered and, since the chat makes use of `Eio.Fiber` anyway, I don't think that it would make sense to avoid `Eio` in the interface.

By giving a closer look into the `term_event_loop`, I realized that my timeout didn't stop the `Term.event` from `Notty_unix` to block everything. (Because the thread that should timeout was also blocked, of course). So I realize the solution was to use `Notty_lwt` instead, which I didn't want to do initially as I wanted to work with pure `Eio` without `Lwt`. I can port `Notty_lwt` to `Notty_eio`, which i'll try after that, but here I use `Notty_lwt` and `Lwt_eio` to integrate with the rest of the application.

I had to make a few refactoring to make the chat module mostly a `Lwt` module but now, it works as I intended. (i.e. The messages get send and the acknowledgement received and processed without waiting for a user input like before)

## Part 8. Try a conversation between the client and the server

So far, I have tested with the client spawning a chat and the server simply logging incoming messages and sending back an "ack".
In the final app, the server will also spawn the same chat app than the client. This should work by calling the same session from the server

Without surprise, it works. But closing one session triggers an error on the other one. We need to do something to close the app gracefully.
As I failed to find a solution and I am waiting for a response to my question on OCaml help's channel, I paused this and moved to the next task.

## Part 9. Display the roundtrip time of messages

To do this, I had to modify the type of `Message` in `Chat` to store the time at which the message was sent and at which time the message was received by the chat.

I also made the type into a variant to differentiate better between messages that were written locally and those received. This make it a bit easier to handle and to display each differently.

## Part 7-bis Notty_eio

While googling on `Eio` for understanding why I get an exception. I ended up on this project [https://gitlab.com/talex5/gemini-eio]() which implement a `Eio` backend for `Notty`, so according to the license, I reused it which allow me to remove `Lwt` from my project. Having all my concurrency handled by `Eio` should make it easier to locate the reason for the exception. Already, I get an `End_of_File` exception where I had a `Eio__core.Suspend` exception before.

## Part 10. Make the application not crash

Trying out different idea, it appears that closing the socket sends a `EoF` which render the flow available for reading but then the parsing fails.
I can fix that either by catching the exception or by first sending a special termination packet.
I decided for the second so that I can differentiate between the "Happy Path" (the other side closes the chat) and the "Sad Path", (the other side sends a wrong packet)

## Part 11. Take care of exception

This part consist of taking care of the "sad path". I have not perform extensive test of the app over the network to detect all kind of possible exception.

The possible errors for the server are:

1. Those from the function `run_server` which shouldn't append in our design
1. Unix Error while binding to the socket and the loopback address

The possible errors for the client are:

1. Impossibility to connect because either can't find the server, the server refused, or the request timeout

Then, when communicating, the communication can be lost or another client/server could implement an erroneous or malicious protocol.
These are reflected by the exceptions in `common.ml`.

## Part 12. Polishing CLI for prod

Now that the project is taking form, it makes no sense anymore the default `host` to localhost, so we change that to a positional argument for the client.

Also with our development, it makes sense to add an optional `username` parameter so let's add it
