%%%
%%% @doc iso_process module.
%%% simple parallel iso message server 
%%%<br>this module is responsible for processing iso messages using iso1993 ascii  message format</br>
%%% @end
%%% @copyright Nuku Ameyibor <nayibor@startmail.com>


-module(iso_process).


-export([start_iso_server/0,send_message/1]).
-include_lib("iso93_spec.hrl").

-define(MTI_SIZE,4).
-define(PRIMARY_BITMAP_SIZE,16).
-define(PORT,8002).
-define(ACCEPTOR_NUM,100).
%%for header size of incoming message
-define(BH,4).


%% @doc this part is for starting the iso server 
-spec start_iso_server()->[pid()] | {error,term()}.	
start_iso_server()->
		{ok, Listen} = gen_tcp:listen(?PORT, [list, {packet, 0},{active, once}]),
		[spawn(fun() -> loop_listen(Listen) end) || _ <- lists:seq(1,?ACCEPTOR_NUM)].


%% @doc this part is for listener socket
-spec loop_listen(port())->[port()] | {error,term()} | fun(). 
loop_listen(Listen_socket)->
		{ok, Socket} = gen_tcp:accept(Listen_socket),	
		loop_receive(Socket,[]).
		

%% @doc this part is for the acceptor socket 
-spec loop_receive(port(),[])->[pos_integer()] | {error,term()} | fun(). 		
loop_receive(Socket,Isom)->
		receive
			{tcp, Socket, Message} ->
				State_new=Isom++Message,
				case length(State_new) of 
					Size when Size < ?BH ->
						inet:setopts(Socket, [{active, once}]),
						loop_receive(Socket,State_new);
					_  ->
						{LenStr, Rest} = lists:split(?BH, State_new),
						Len = erlang:list_to_integer(LenStr)+?BH,
						case length(State_new) of 
							SizeafterHead when Len =:= SizeafterHead ->
								Response_message = process_message(Rest),
								io:format("~nParsed Iso Map ~p~n",[Response_message]),
								inet:setopts(Socket, [{active, once}]),
								loop_receive(Socket,[]);
							SizeafterHead when Len < SizeafterHead ->
								inet:setopts(Socket, [{active, once}]),
								loop_receive(Socket,State_new)
						end
				end;
			{tcp_closed, _Socket} ->
				io:format("Server socket closed~n" );
			{tcp_error, _Socket, _}->
				io:format("Error closed~n" )					
		end.						
								
	
%% @doc this part is for sending iso messages for parsing 
-spec send_message([pos_integer()])->{error,term()} | fun(). 			
send_message(Message)->
		{ok, Socket} = gen_tcp:connect("localhost", ?PORT, [list, {packet, 0},{active, once}]),
		gen_tcp:send(Socket,Message).
		
		

%% @doc this part accepts a 1993 ascii iso8583 message and extracts the mti,bitmap,data elements into a map object 
%% exceptions can be thrown here if the string for the message hasnt been formatted well but they should be caught in whichever code is calling the system 
-spec process_message([pos_integer()])->map().		
process_message(Rest)->		
		Mti_size = ?MTI_SIZE,
		Primary_Bitmap_size = ?PRIMARY_BITMAP_SIZE,
		io:format("~nrequest_mti : ~p",[lists:sublist(Rest,Mti_size)]),		
		Bitmap_size = case lists:nth(1,string:right(integer_to_list(list_to_integer([lists:nth(5,Rest)],16),2),4,$0)) of
						48 -> 16;
						49 -> 32
						end,
		%%io:format("~n~nbitmap size is:~p",[Bitmap_size]),
		%%io:format("~nbmp vals:~p~nraw vals:~w~nvals:~p",[lists:map(fun(X)->string:right(integer_to_list(list_to_integer([X],16),2),4,$0)end,lists:sublist(Rest,Mti_size+1,Bitmap_size)),lists:sublist(Rest,Mti_size+1,Bitmap_size),lists:sublist(Rest,Mti_size+1,Bitmap_size)]),
		Bitmap_transaction = lists:flatten(lists:map(fun(X)->string:right(integer_to_list(list_to_integer([X],16),2),4,$0)end,lists:sublist(Rest,Mti_size+1,Bitmap_size))),
		
		%%add bitmap as well as mti to map which holds data elements so they can help in processing rules 
		Mti_Data_Element = maps:from_list([{ftype,ans},{fld_no,0},{name,<<"Mti">>},{val_list_form,lists:sublist(Rest,Mti_size)}]),
		Bitmap_Data_ELement = maps:from_list([{ftype,b},{fld_no,1},{name,<<"Bitmap">>},{val_binary_form,Bitmap_transaction},{val_list_form,lists:sublist(Rest,Mti_size+1,Bitmap_size)}]),
		Map_Data_Element1 =  maps:put(<<"_mti">>,Mti_Data_Element,maps:new()), 
		Map_Data_Element = maps:put(<<"_bitmap">>,Bitmap_Data_ELement,Map_Data_Element1),
		Start_index = Mti_size+Primary_Bitmap_size+1,
		%%io:format("~nkeys and values so far are ~p",[Map_Data_Element]),
		OutData = lists:foldl(fun(X,_Acc={Data_for_use_in,Index_start_in,Current_index_in,Map_out_list_in}) when X =:= 49->						
								    {Ftype,Flength,Fx_var_fixed,Fx_header_length,DataElemName}=?SPEC(Current_index_in),
									case Fx_var_fixed of
										fx -> 
											Data_Element = lists:sublist(Data_for_use_in,Index_start_in,Flength),
											New_Index = Index_start_in+Flength ;	
										vl ->
											Vl_value = list_to_integer(lists:sublist(Data_for_use_in,Index_start_in,Fx_header_length)),
											Start_val = Index_start_in + Fx_header_length , 										
											Data_Element = lists:sublist(Data_for_use_in,Start_val,Vl_value),
											New_Index = Start_val+Vl_value
									end,
									NewData  = maps:from_list([{ftype,Ftype},{fld_no,Current_index_in},{name,DataElemName},{val_list_form,Data_Element}]),
									NewMap = maps:put(Current_index_in,NewData,Map_out_list_in),
									Fld_num_out = Current_index_in + 1,
									%%io:format("~nkeys and values so far are ~p",[NewMap]),
									{Data_for_use_in,New_Index,Fld_num_out,NewMap};
								(X,_Acc={Data_for_use_in,Index_start_in,Current_index_in,Map_out_list_in}) when X =:= 48->
									Fld_num_out = Current_index_in + 1,						
									{Data_for_use_in,Index_start_in,Fld_num_out,Map_out_list_in}
							 end,
						{Rest,Start_index,1,Map_Data_Element},Bitmap_transaction),
		{_,_,_,FlData} = OutData,
		%%io:format("~nkeys and values so far are ~p",[FlData]),
		FlData.
