# Getting things Done

From the specification, I decide to split the software in 3 main components:

1. A cli to lunch the software in the correct mode
1. A network layer
1. A graphical UI interfaces

So after initializing a new project with dune. I start working on these part.

## Part 1. Building the CLI (CmdLiner)

When working at LigoLang, I ended up redesign the CLI and porting it `CmdLiner` to JaneStreet's `Command`. Thus, I add plenty of experience and it went straight forward.

I choose to use `CmdLiner` you don't need to install the whole `Core` library, which I don't need.

For this part, I simply fill the `main.ml` file of the bin folder with the command definition. Calling 2 new lib `client` and `server`.

For simplicity during dev, host is default to localhost and port to 8080

## Part 2. Simple web communication (Eio)

I came across `Lwt` code before but never actually used. Since I like to use cutting edge tech or experimental tech in my side-project,
it made sense to me to use the new OCaml-multicore library `Eio`.

Nothing specific to say here. It was very easy to setup a simple server and tcp connection, and after playing around with `Flow`, to find out how to use `Buf_read` and `Buf_write`.

On the client, I codded a simple loop that listen to stdin, send a message to the server and wait for the server to send back and acknowledgement. On the server, I just display the received message to check.
(I also made a primitive message lib but not very relevant at the point).

While I only really communicate in one direction, my goal was to validate that I am able to transmit message and it was met. I just wanted to make a chat app that would be use by both the client and server, so I went on with it.

## Part 3. User interface (Minttea)

Came the interesting part, as I never made a GUI in OCaml before. My experience with GUI are web interface (`Rescript-react`) and 1 `C` and 1 `Java` application during uni, 10 years ago, so things have change since then.

I went on to search for graphic libraries for OCaml, I could either use a `GUI` but I didn't want to bother with positioning and such, or one of a few `TUI` and I never did a app in terminal before so I choose it. Also since the specification doing care about the front-end, the simpler, the better. (I even considerer using a file open with `less` to display the message history but let's be serious)

I found out the `Minttea` lib that first, has a cool name, and that's important. And second use the `ELM` architecture, very familiar to a react programmer like me and I was able to make the equivalent of the grocery list app, i.e. a text field and a list of all the previous input.

Great now, I need to connect the chat with the network socket and that should work

## Part 4. Connecting people

So intuitively, I assumed that if I extend my chat with an input pipe and output pipe and add in the list when I get something from the input pipe and write on the output pipe. I should be more or less done.

I did several attempts with this idea, adding the pipe in the model or as a parameter of the update closure but the message got transmitted only when I close the application which to me means that I don't let the scheduler release the chat threads and run the communication thread.
So I tried to yield the chat thread which did send the message but also triggered an exception `Suspend` from `Eio` and I couldn't find why and how to prevent it.

Looking further into the implementation on Minttea, it uses the `Riot` lib for handling the thread. My understanding is that when running the chat app. I run a new "`Riot` scheduler" and when I try to `yield` my Eio fiber, it goes through the "`Riot` scheduler" then the "`Eio scheduler`" and when going back to fiber with "`Riot` scheduler" there is some interference somewhere. With not a better understanding of the issue and no result from my web searches, I decided that I should not try to integrate Minttea and Eio anymore. So I can either replace `Eio` with `Riot` and use their net library but I really wanted to use `Eio` and I am pretty happy with it. Or use another front-end library which would also provide me experience with more popular UI lib so, that is the option I chose.

## Part 3 again. User interface (Notty)

This part was actually quite straightforward. I reimplemented the main_loop and ended_up with a similar API so I could reuse what I did, and ended up with and ELM architecture, but now the UI don't run in separate thread.
