# One-to-one

Doing some OCaml for an interview.

### Problem description

```
Simple one on one chat.

Application should start in two modes:
- as a server, waiting for one client to connect or
- as a client, taking an IP address (or hostname) of server to connect to.

After connection is established user on either side (server and client) can
send messages to the other side. After connection is terminated by the client -
server continues waiting for another client. The receiving side should
acknowledge every incoming message (automatically send back "message received"
indication), sending side should show the rountrip time for acknowledgment.
Wire protocol shouldn't make any assumptions on the message contents (e.g.
allowed byte values, character encoding, etc).

UI is your choice - can be just a console.

Requirements:

- Application is to be compiled and run on linux
- Implementation language : OCaml
- Can use any 3rd-party general-purpose libraries (extlib, lwt, containers,
  etc.)

Primary objectives: robustness, code simplicity and maintainability.
```

### Solution description

The program interacts with users over the command line. All user input is taken
from stdin, and all the program's output is given to stdout (and stderr in the
case that something goes terribly wrong).

When you run the program, you are asked to pick a running mode: Client or
server. Once you've entered the startup information, you'll be prompted to
"press enter to continue".

If the program is started in server mode, you are asked to pick a port to run
on. The program then goes to a prompt, where users can send messages to the
last client who contacted them. If no client has sent them a message yet, then
this will be explained to them if they try to send a message.

If the program is started in client mode then, the program will
prompt the user for a socket (host:port) to connect to an instance in server
mode. The client can then begin sending and receiving messages with the server.
Note that the client has to initiate contact by sending the first message. Once
the client has sent the first message, the server will be able to send messages
to them too.

Either party can end their session by typing "/exit". This of course means that
the message /exit can't be sent without some additional logic in the program to
enable that. This exit functionality is useful for testing the program
automatically though, and so users are expected to accommodate to not being
able to send '/exit'.

When a counter-party in a chat exits, the messages sent by the remaining party
are not received, of course. They are informed of this.

### Areas for improvement

- Roundtrip time for message acknowledgement
- Sending arbitrary messages
- Robustness: Unexpected behaviour in automated tests is making it difficult to
  automatically validate the program's behaviour in different scenarios.
- Code simplicity/maintainability:
  - The chat implementation is currently coupled to the wire protocol.
  - There is some unaddressed duplication between the server and the client.
  - There's a lack specifically of end-to-end automatic tests.
  - There's a lack of separation for log output vs output to be read by users.

## Running the program

In all cases, start from the root directory of this repository. That is,
`pwd | xargs basename` should output "one-to-one".

### Pre-requisites

#### Running locally

Pre-requisites are`opam` and `dune`, primarily. Here are the outputs of some
commands I ran, which you may find informative:

```
romo$ opam --version
2.0.7
romo$ dune --version
2.6.2
romo$ ocaml --version
The OCaml toplevel, version 4.10.0 
romo$
```

#### Running in a docker container

You need docker of course.

Build the container image with`

```
./deploy/build-container.sh
```

If you end up with dangling containers from being fast-and-loose about your
docker run calls, then use the script `./deploy/remove-dangling-images.sh`.

Once you've built the docker image, run `./deploy/docker-interactive.sh` to
enter a shell in that container. You'll start in the correct directory. From
there, you can run all the same commands that you would run if you were running
it on the host machine, as described below.

### Run the tests

```
cd test
./run.sh
```

Which should give you output like this:

```
.........
Ran: 9 tests in: 1.11 seconds.
OK
```

#### Run the executable

```
cd exec
./run.sh
```

An example server run looks like this:

```
Pick a mode ('client' or 'server')
> server
Which port should this server run on? (e.g. '8081')
> 9090
Running in server mode on port 9090 

s> Press enter to continue > 

>s> hello 
s> hi             
confirmed

s> 
```

A corresponding example client run looks like this:

```
Pick a mode ('client' or 'server')
> client
What's the socket of the server in the format host:port? (e.g. 'localhost:8080')
> localhost:9090
Running in client mode against server at host localhost on port 9090 

c> Press enter to continue > 
hello
confirmed

c> 
>c> hi 
c>
```

### Technical choices with reasoning

This section contains lightweight, subjective, technical reasoning for some
choices made in the building of this program. Of course, in all cases, my
evaluation is that the pros outweigh the cons, and the software reflects that.

#### Communication protocol: Plain HTTP

Pros:

- Library support likely to be better than for other protocols, even mainstream
  ones like web sockets. When building using unfamiliar tools (I am new to
  OCaml), sticking to simpler use-cases can be the difference between
  delivering working software on time, versus using up your time in wrestling
  with documentation-less, example-less third party libraries.

Cons:

- As a protocol for this functionality, it would be a valid criticism to say
  that HTTP as a whole is heavyweight.
- Using plain HTTP isn't inherently bidirectional, as opposed to
  something like web sockets, which I think would be a more natural fit for
  this problem.
  
#### Program interface: Interactive

Pros:

- Makes sense as part of the program's flow from a user perspective.
- Writing code that reads directly from stdin is easier than writing code to
  parse command-line arguments, I would guess. Especially given that I have an
  understanding of how to read from stdin anyway as part of the chat
  functionality.

Cons:

- You'd have to pipe text into the program in order to get it into a
  predetermined state automatically (i.e. without human interaction). As
  mentioned above however, this is a chat program, and so I would guess that
  this use case doesn't demand support. The program is designed such that this
  would be easy to change anyway, so I don't think this is a big problem.