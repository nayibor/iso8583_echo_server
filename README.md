##What is this

This repository is for teaching the basics of how to process iso8583 transactions using erlang.  

code relies on the [iso8583_erl](https://github.com/nayibor/iso8583_erl) library for packing and unpacking iso8583 messages.

the project is in the form of an echo server where messages are sent to an iso8583  tcp server and are echoed back to the sender.

**running the project**

make sure you have erlang and rebar3 installed and  in your path.

make sure port 8002 is free or you change the port configuration in the `sys.config` file.

run `rebar3 compile` then run `rebar3 shell`.

this should successfully compile the project and start the project with an interactive shell

**testing echoing functionality**

to test the echoing functionalty you can run the following command in the interactive shell which will send a sample iso8583 message to the tcp server process which will receive,display the received message and send back an echo response.

`2> iso8583_echo_server_app:test().`

**packing**

`iso8583_echo_server_app:test/0`

this contains code for packing the iso8583 message as well as creating and sending it off to a tcp server.

packing is done based on a specfication found in the `priv/interface_conf`

**unpacking**

`iso8583_echo_server_sock_serv:process_transaction/2`

this part contains code for unpacking the sent message and echoing it back to the sender
