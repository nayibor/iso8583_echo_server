%%%
%%% @doc iso8583_echo_server_sock_serv module.
%%%<br>this module is responsible for accepting conections from external interfaces and passing it to the asci processor for furthe processing </br>
%%% @end


-module(iso8583_echo_server_sock_serv).
-behaviour(gen_server).
-behaviour(ranch_protocol).

-record(state, {iso_message=[],socket,ref,transport,event_handler,bhead,spec_iso,spec_mti}). % the current socket
 

%%for ranch stuff
-export([start_link/3]).

%%for gen server stuff
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,code_change/3,handle_continue/2, terminate/2]).
 
 %% macros for messages received on socket
-define(SOCK(Msg), {tcp, _Port, Msg}).


-type state() :: #state{}.



%% @doc this is used for starting up the ranch accepting socket 
start_link(Ref, Transport, Opts) ->
		{ok, proc_lib:spawn_link(?MODULE, init, [{Ref, Transport, Opts}])}.


%% @doc this is the init for starting up the socket using ranch
init({Ref, Transport,[Bheader,Specification]}) ->
		gen_server:enter_loop(?MODULE, [],#state{ref=Ref,iso_message=[],transport=Transport,bhead=Bheader,spec_iso=Specification},{continue,setup_socket}).


%% @doc for setting up the ranch socket
handle_continue(setup_socket, S = #state{transport=Transport,ref=Ref})->
		{ok, Socket} = ranch:handshake(Ref),
		ok = Transport:setopts(Socket,[list,{active, once}]),
		{noreply,S#state{socket=Socket}}.



%% @doc this call is for all call messages 
-spec handle_call(term(),pid(),state()) -> term().
handle_call(E, From, State) ->
		io:format("~nd call data is ~p~n",[{E,From}]),
		{noreply, State}.

%% unknown casts
handle_cast(Cast_data, S) ->
		io:format("~nd call data is ~p~n",[{Cast_data}]),
		{noreply,S}.


%% @doc handles connections and proceses the iso messages which are sent through the connection 
%% this function is the main entry point into the application from external sockets which are connected to it 		
-spec handle_info(term(),state()) -> {term(),state()}.    
handle_info(?SOCK(Str_Sock), State_old = #state{socket=AcceptSocket_process,iso_message=Isom_so_far,transport=Transport}) ->
		S = process_transaction(?SOCK(Str_Sock),State_old),
	    Transport:setopts(AcceptSocket_process, [{active, once}]),
		S;
         
	 		 	
handle_info({tcp_closed, _Socket}, S) ->
		io:format("~nSocket Closed"),							
		{stop, normal, S};
    
    
handle_info({tcp_error, _Socket, _}, S) ->
		{stop, normal, S}; 


%% @doc info coming in from as a result of messages received maybe from othe processes 
handle_info(_, S) ->
		{noreply, S}.


%% @doc for code changes
-spec code_change(string(),state(),term())->{ok,state()}|{error,any()}.
code_change(_OldVsn, State, _Extra) ->
		{ok, State}.

%% @doc ranch termination
%% the gen event will have to be terminated here also 
%%terminate(_Reason, #state{socket=AcceptSocket_process,transport=Transport,event_handler=Pid}) ->
terminate(_Reason, #state{socket=AcceptSocket_process,transport=Transport}) ->
		ok = Transport:close(AcceptSocket_process),
		%%ok = gen_event:stop(Pid),
		error_logger:error_msg("~nterminate reason: ~p", [_Reason]),
		ok.


%% @doc this is for processing the transactions which come through the system
process_transaction({_,_,Msg}, S = #state{socket=AcceptSocket,iso_message=Isom,transport=Transport,bhead=Bheader,spec_iso=Specification})->
		State_new = lists:flatten([Isom,Msg]), 
		%%io:format("~nmessage is ~psize is ~p bhead is ~p", [Msg,length(State_new),Bheader]),		
		case length(State_new) of 
			Size when Size < Bheader -> 
				{noreply, S#state{iso_message=State_new}};
			_  ->
				{LenStr, Rest} = lists:split(Bheader, State_new),
				Len = erlang:list_to_integer(LenStr),
				case erlang:length(Rest) of 
					SizeafterHead when Len =:= SizeafterHead ->
						Map_iso = iso8583_erl:unpack(Rest,Specification),
						io:format("~n message received is ~p~n", [Map_iso]),
						Iso_Response = [Mti,Bitmap_final_bit,Fields_list] = iso8583_erl:pack(Map_iso,Specification),
						Final_size = iso8583_erl:get_size_send(Iso_Response,Bheader),
						Final_socket_response = [Final_size,Iso_Response],
					    io:format("~n echoing message back ~n",[]),	
						ok = send(AcceptSocket,Final_socket_response,Transport),
						{noreply, S#state{iso_message=[]}};
					SizeafterHead when Len < SizeafterHead ->
						{noreply, S#state{iso_message=State_new}}
				end
		end.


%% @doc for sending information through the socket
-spec send(port(),[pos_integer()],port())->ok|{error,any()}.
send(Socket, Str,Transport) ->
		ok = Transport:send(Socket,Str).
