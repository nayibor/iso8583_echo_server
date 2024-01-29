##What is this

This repository is for teaching the basics of how to process iso8583 transactions using erlang.  

code relies on the [iso8583_erl](https://github.com/nayibor/iso8583_erl) library for packing and unpacking iso8583 messages.

the project is in the form of an echo server where messages are sent to an iso8583  tcp server and are echoed back.

there is two main modules to check out to see how to perform the packing and unpacking

**packing**

`iso8583_echo_server_app:test/0`

this contains code for packing the iso8583 message as well as creating and sending it off to a tcp server.

packing is done based on a specfication found in the `priv/interface_conf`

**unpacking**

`iso8583_echo_server_sock_serv:process_transaction/2`

this part contains code for unpacking the sent message and echoing it back to the sender
