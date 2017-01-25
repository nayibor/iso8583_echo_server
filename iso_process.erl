%%%
%%% @doc iso_process module.
%%% simple parallel iso message server 
%%%<br>this module is responsible for processing iso messages using iso1993 ascii  message format</br>
%%% @end
%%% @copyright Nuku Ameyibor <nayibor@startmail.com>


-module(iso_process).


-export([start_iso_server/0,send_message/1,pad_data/3]).


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
-spec loop_receive(port(),[pos_integer()])->term() | {error,term()} | fun(). 		
loop_receive(Socket,Isom)->
		receive
			{tcp, Socket, Message} ->
				State_new = Isom++Message,
				case length(State_new) of 
					Size when Size < ?BH ->
						inet:setopts(Socket, [{active, once}]),
						loop_receive(Socket,State_new);
					_  ->
						{LenStr, Rest} = lists:split(?BH, State_new),
						Len = erlang:list_to_integer(LenStr)+?BH,
						case length(State_new) of 
							SizeafterHead when Len =:= SizeafterHead ->
								Response_message = process_message({binary,Rest}),
								io:format("~nParsed Iso Map~n ~p~n",[Response_message]),
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
		gen_tcp:send(Socket,Message),
		ok = gen_tcp:close(Socket).
		
		
-spec process_message([{list | binary,pos_integer()}])->map().			
%% @doc this part is for usage of binaries		
process_message({binary,Rest})-> 
		 Bin_message = erlang:list_to_binary(Rest),
		 io:format("~nmessageis ~p",[Bin_message]),
		 Fthdig = binary:part(Bin_message,4,1),
		 Fth_base16 = erlang:binary_to_integer(Fthdig,16),
		 Fth_base2 = erlang:integer_to_binary(Fth_base16,2),
		 Pad_left_z_basetwo  = pad_data(Fth_base2,4,<<"0">>),
		 io:format("~n4base pad is ~p",[Pad_left_z_basetwo]),
		 Bitmap_test_num = binary:part(Pad_left_z_basetwo,0,1),
		 Bitmap_size = case Bitmap_test_num of
							<<"0">> -> 16;
							<<"1">> -> 32
						end,
		Bitmap_Segment = binary:part(Bin_message,?MTI_SIZE,Bitmap_size),
		Bitmap_transaction = << << (convert_base(One)):4/binary >>  || <<One:1/binary>> <= Bitmap_Segment >>,
		
		%%add bitmap as well as mti to map which holds data elements so they can help in processing rules 
		Mti_Data_Element = maps:from_list([{ftype,ans},{fld_no,0},{name,<<"Mti">>},{val_binary_form,binary:part(Bin_message,0,?MTI_SIZE)}]),
		Bitmap_Data_ELement = maps:from_list([{ftype,b},{fld_no,1},{name,<<"Bitmap">>},{val_binary_form,Bitmap_transaction},{val_hex_form,Bitmap_Segment}]),
		Map_Data_Element1 =  maps:put(<<"_mti">>,Mti_Data_Element,maps:new()), 
		Map_Data_Element = maps:put(<<"_bitmap">>,Bitmap_Data_ELement,Map_Data_Element1),
		Start_index = ?MTI_SIZE+Bitmap_size,
		{Map_Data_Element,Start_index};

%% @doc this part accepts a 1993 ascii iso8583 message and extracts the mti,bitmap,data elements into a map object 
%% exceptions can be thrown here if the string for the message hasnt been formatted well but they should be caught in whichever code is calling this function
process_message({list,Rest})->		
		
		Fthdig = [lists:nth(5,Rest)] ,
		Fth_base16 = list_to_integer(Fthdig,16),
		Fth_base2 = integer_to_list(Fth_base16,2),
		Pad_left_z_basetwo = string:right(Fth_base2,4,$0),
		Bitmap_test_num = lists:nth(1,Pad_left_z_basetwo),        
		Bitmap_size = case Bitmap_test_num of
						48 -> 16;
						49 -> 32
						end,
		
		Bitmap_Segment = lists:sublist(Rest,?MTI_SIZE+1,Bitmap_size),
		Fun_ret_bitmap_binary_elem = fun(X)->
										Sing_item = list_to_integer([X],16),
										Integer_sing_item = integer_to_list(Sing_item,2), 	
										string:right(Integer_sing_item,4,$0)
									  end ,
		Bitmap_list_raw = lists:map(Fun_ret_bitmap_binary_elem,Bitmap_Segment),
		Bitmap_transaction = lists:flatten(Bitmap_list_raw),
		
		%%add bitmap as well as mti to map which holds data elements so they can help in processing rules 
		Mti_Data_Element = maps:from_list([{ftype,ans},{fld_no,0},{name,<<"Mti">>},{val_list_form,lists:sublist(Rest,?MTI_SIZE)}]),
		Bitmap_Data_ELement = maps:from_list([{ftype,b},{fld_no,1},{name,<<"Bitmap">>},{val_binary_form,Bitmap_transaction},{val_list_form,lists:sublist(Rest,?MTI_SIZE+1,Bitmap_size)}]),
		Map_Data_Element1 =  maps:put(<<"_mti">>,Mti_Data_Element,maps:new()), 
		Map_Data_Element = maps:put(<<"_bitmap">>,Bitmap_Data_ELement,Map_Data_Element1),
		Start_index = ?MTI_SIZE+?PRIMARY_BITMAP_SIZE+1,
		%%io:format("~nkeys and values so far are ~p",[Map_Data_Element]),
		OutData = lists:foldl(fun(X,_Acc={Data_for_use_in,Index_start_in,Current_index_in,Map_out_list_in}) when X =:= 49->						
								    {Ftype,Flength,Fx_var_fixed,Fx_header_length,DataElemName} = get_spec_field(Current_index_in),
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
		
		
		
%% @doc this part gets the specifications for a particular field 
-spec get_spec_field(pos_integer())->{atom(),pos_integer(),atom(),pos_integer(),binary()} .
get_spec_field(DataElem)->
		case DataElem of
			1	->{b,16,fx,0,<<"Secondary Bitmap">>};%%small change 
			2 	->{n,19,vl,2,<<"Pan">>};
			3 	->{n,6,fx,0,<<"Processing Code">>};
			4 	->{n,12,fx,0,<<"Amount Transaction">>};
			5 	->{n,12,fx,0,<<"Amount Settlement">>};
			6 	->{n,12,fx,0,<<"Amount, cardholder billing">>};
			7 	->{n,10,fx,0,<<"Transmission date & time MMDDhhmmss">>};
			8 	->{n,8,fx,0,<<"Amount, Cardholder billing fee">>};
			9 	->{n,8,fx,0,<<"Conversion rate, Settlement">>};
			10	->{n,8,fx,0,<<"Conversion rate, cardholder billing">>};
			11	->{n,6,fx,0,<<"System Trace Audit Number">>};
			12	->{n,12,fx,0,<<"Time, Local transaction (YYMMDDhhmmss)">>};
			13	->{n,4,fx,0,<<"Date, Local transaction (MMDD)">>};
			14	->{n,4,fx,0,<<"Date, Expiration YYMM">>};
			15	->{n,6,fx,0,<<"Settlement Date YYMMDD">>};
			16	->{n,4,fx,0,<<"Conversion Date MMDD">>};
			17	->{n,4,fx,0,<<"Date, Capture MMDD">>};
			18	->{n,4,fx,0,<<"Merchant Type">>};
			19	->{n,3,fx,0,<<"Country Code">>};
			20	->{n,3,fx,0,<<"Country Code/Pan Extended">>};
			21	->{n,3,fx,0,<<"Country Code/Forwarding Institution">>};
			22	->{an,12,fx,0,<<"Pos Data Code">>};
			23	->{n,3,fx,0,<<"Card Sequence Number">>};				
			24	->{n,3,fx,0,<<"Function Code">>};
			25	->{n,4,fx,0,<<"Message Reason Code">>};
			26	->{n,4,fx,0,<<"Card Acceptor Business Code">>};
			27	->{n,1,fx,0,<<"Approval Code">>};
			28	->{n,6,fx,0,<<"Reconciliation Date YYMMDD">>};
			29	->{n,3,fx,0,<<"Reconciliation Indicator">>};
			30	->{n,24,fx,0,<<"Amount Original">>};
			31	->{ans,99,vl,2,<<"Acquirer Reference Data">>};
			32	->{n,11,vl,2,<<"Acquirre Identification Code">>};
			33	->{n,11,vl,2,<<"Forwarding Identification Code">>};
			34	->{ns,28,vl,2,<<"Pan Extended">>};
			35	->{ns,37,vl,2,<<"Track 2 Data">>};
			36	->{ns,104,vl,2,<<"Track 3 Data">>};
			37	->{anp,12,fx,0,<<"Retrieval Reference Number">>};
			38	->{anp,6,fx,0,<<"Approval Code">>};
			39	->{n,3,fx,0,<<"Response Code">>};
			40	->{n,3,fx,0,<<"Service Code">>};
			41	->{ans,8,fx,0,<<"Terminal Id">>};
			42	->{ans,15,fx,0,<<"Card Acceptor Identication Code">>};
			43	->{ans,99,vl,2,<<"Name/Location">>};
			44	->{ans,99,vl,2,<<"Additional Response Data">>};
			45	->{ans,76,vl,2,<<"Track 1 Data">>};
			46	->{ans,204,vl,2,<<"Amount/Fees">>};
			47	->{ans,999,vl,3,<<"Additional Data National">>};%%small change
			48	->{ans,999,vl,3,<<"Additional Data Private">>};	%%small change
			49	->{aorn,3,fx,0,<<"Currency Code Transaction">>};
			50	->{aorn,3,fx,0,<<"Currency Code Reconciliaton">>};
			51	->{aorn,3,fx,0,<<"Currency Code Cardholder Billing">>};
			52	->{hex,8,fx,0,<<"Pin Data">>};
			53	->{b,48,vl,2,<<"Crypto Info">>};
			54	->{ans,120,vl,2,<<"aAmount Additional">>};
			55	->{b,255,vl,2,<<"Currency Code Cardholder Billing">>};
			56	->{n,35,vl,2,<<"Original Data Elements">>};
			57	->{n,3,fx,0,<<"Authorization Life Cycle Code">>};
			58	->{n,11,vl,2,<<"Authorization Agent Inst Id Code">>};
			59	->{ans,999,vl,2,<<"Transport Code">>};
			60	->{ans,999,vl,3,<<"Reserved For Nation Use">>};%%small change
			61	->{ans,999,vl,3,<<"Reserved For Nation Use">>};%%small change
			62	->{ans,999,vl,3,<<"Reserved For Nation Use">>};%%small change
			63	->{ans,999,vl,3,<<"Reserved For Nation Use">>};%%small change
			64	->{hex,8,fx,0,<<"Mac Data">>};
			65	->{t,8,fx,0,<<"Reserved for Iso Use">>};
			66	->{ans,204,vl,2,<<"Amount Original Fees">>};	
			67	->{n,2,fx,0,<<"Extended Payment Data">>};				
			68	->{n,3,fx,0,<<"Country Code,Receiving Institution">>};				
			69	->{n,3,fx,0,<<"Country Code,Settlement Institution">>};				
			70	->{n,3,fx,0,<<"Country Code,Authorizing Agent  Institution">>};				
			71	->{n,8,fx,0,<<"Message Number">>};				
			72	->{ans,255,vl,2,<<"Data Record">>};				
			73	->{n,6,fx,0,<<"Date Action YYMMDD">>};				
			74	->{n,10,fx,0,<<"Credits Number">>};
			75	->{n,10,fx,0,<<"Credits Reversal Number">>};				
			76	->{n,10,fx,0,<<"Debits Number">>};				
			77	->{n,10,fx,0,<<"Debits Reversal Number">>};				
			78	->{n,10,fx,0,<<"Transfer Number">>};				
			79	->{n,10,fx,0,<<"Transfer Reversal Number">>};				
			80	->{n,10,fx,0,<<"Enquiries Number">>};				
			81	->{n,10,fx,0,<<"Authorizations Number">>};				
			82	->{n,10,fx,0,<<"Enquiries Reversal Number">>};				
			83	->{n,10,fx,0,<<"Payments Number">>};				
			84	->{n,10,fx,0,<<"Payments Reversal Number">>};				
			85	->{n,10,fx,0,<<"Fee Collection Number">>};				
			86	->{n,16,fx,0,<<"Credits Amount">>};				
			87	->{n,16,fx,0,<<"Credits Reversal Amount">>};				
			88	->{n,16,fx,0,<<"Debits Amount">>};				
			89	->{n,16,fx,0,<<"Debits Reversal Amount">>};				
			90	->{n,10,fx,0,<<"Authrization Reversal Number">>};				
			91	->{n,3,fx,0,<<"Country Code.Transaction Destination Institution">>};				
			92	->{n,3,fx,0,<<"Country Code.Transaction Originator Institution">>};				
			93	->{n,11,vl,2,<<"Transaction Destination Institution Id Code">>};				
			94	->{n,11,vl,2,<<"Transaction Originator Institution Id Code">>};				
			95	->{ans,99,vl,2,<<"Transaction Originator Institution Id Code">>};				
			96	->{b,255,vl,2,<<"Key Management Data">>};				
			97	->{n,16,fx,0,<<"Amount Net Reconciliation">>};				
			98	->{ans,25,fx,0,<<"Third Party Information">>};				
			99	->{an,11,vl,2,<<"Settlement Instituition Id">>};				
			100	->{n,11,vl,2,<<"Receiving Instituition Id">>};				
			101	->{ans,17,vl,2,<<"File Name">>};				
			102	->{ans,28,vl,2,<<"Account Number">>};				
			103	->{ans,28,vl,2,<<"Account Number 2">>};				
			104	->{ans,100,vl,2,<<"Transaction Description">>};				
			105	->{n,16,fx,0,<<"Credits ChargeBack Amount">>};				
			106	->{n,16,fx,0,<<"Debits ChargeBack Amount">>};				
			107	->{n,10,fx,0,<<"Credits Chargeback Number">>};				
			108	->{n,10,fx,0,<<"Debits Chargeback Number">>};				
			109	->{ans,84,vl,2,<<"Credits Fee Amount">>};				
			110	->{ans,84,vl,2,<<"Debits Fee Amount">>};				
			111	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			112	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			113	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			114	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			115	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			116	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			117	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			118	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			119	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			120	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			121	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			122	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			123	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			124	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			125	->{ans,255,vl,3,<<"Reserved For Iso Use">>};				
			126	->{ans,255,vl,3,<<"Reserved For Iso Use">>}				
		end .

%%this is for padding a binary up to a length of N digits with a binary character
%%mostly used in the bitmap
%%pad character size <2

pad_data(Bin,Number,Character)when is_binary(Bin),is_integer(Number),Number > 0,is_binary(Character),size(Character)<2 -> pad_data(Bin,Number,Character,Number-size(Bin)).
pad_data(Bin,Number,Character,Counter) when Counter > 0 -> pad_data(<<Character/binary,Bin/binary>>,Number,Character,Counter-1);
pad_data(Bin,_Number,_Character,Counter) when Counter =< 0 -> Bin.

%%this is for creating correct interpretation of the bitmap for a binary 
convert_base(Data_Base_16)->
		Fth_base16 = erlang:binary_to_integer(Data_Base_16,16),
		Data_base2 = erlang:integer_to_binary(Fth_base16,2),
		pad_data(Data_base2,4,<<"0">>).

