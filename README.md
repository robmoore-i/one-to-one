# One-to-one

Trying some OCaml.

### Program description

The program interacts with users over the command line. All user input is taken
from stdin, and all the program's output is given to stdout (and stderr in the
case that something goes terribly wrong).

When you run the program, you are asked to pick a running mode: Client or
server. In each case, you are asked to pick a port number on which your
instance of the program will be reachable by a chat partner.

If the program is started in server mode, the program will do nothing until an
instance in client mode initiates a connection. If the program is started in
client mode then, the program will additionally prompt the user for a socket
(host:port) to connect to an instance in server mode.

Once a connection is made between two instances, they exchange messages until
one party terminates the connection.

Once a connection is terminated, the process of the instance running in client
mode will finish. The instance running in server mode will continue and await a
connection from a new client instance.

### Running the program

#### Run the executable

```
cd exec
./run.sh
```

#### Run the tests

```
cd test
./run.sh
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
  with documentation-less, example-less dependencies.

Cons:

- As a protocol for this functionality, it would be a valid criticism to say
  that HTTP as a whole is heavyweight.
- Using plain HTTP isn't inherently bidirectional, as opposed to
  something like web sockets, which would be a more natural fit for this
  problem.
  
#### Program interface: Interactive

Pros:

- Makes sense as part of the program's flow from a user perspective.
- Writing code that reads directly from stdin is easier than writing code to
  parse command-line arguments, probably. 

Cons:

- You'd have to pipe text into the program in order to get it into a
  predetermined state automatically (i.e. without human interaction). As
  mentioned above however, this is a chat program, and so I would guess that
  this use case doesn't demand support.
  
#### Developed on a mac

Pros:

- This is the machine I have available to me at home, so using it is less
  effort than spinning up a VM or docker image for development. I am lazy,
  so this is an important factor.

Cons:

- OCaml programs typically run on Linux machines, and this particular one is
  intended to.
- Not all OCaml libraries are cross-platform, so it working on Mac is no
  guarantee that it will work on Linux.

### Misc

#### Issues raised while learning

- Ounit2 assertion failure messages aren't what I hoped for: https://github.com/gildor478/ounit/issues/20
- Lwt_io.getaddrinfo hangs intermittently (at least on Mac): https://github.com/ocsigen/lwt/issues/797
