%%%-------------------------------------------------------------------
%% @doc iso8583_echo_server public API
%% @end
%%%-------------------------------------------------------------------

-module(iso8583_echo_server_app).

-behaviour(application).

-export([start/2, stop/1,test/0]).

start(_StartType, _StartArgs) ->
	{ok,Interfaces} = application:get_env(iso8583_echo_server,interfaces),
	%%io:format("~ninterface configurations are ~p",[Interfaces]),
	load_interfaces(Interfaces),
    iso8583_echo_server_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
load_interfaces(Interfaces)->
	lists:map(fun(Interface)-> 
		#{port := Port_interface,name := Name_interface,limit := Limit_interface,byte_header_size := Byte_header_size_interface,
		server_address := Server_Address_interface,spec_path := Spec_path_interface} = Interface,
		Specification = iso8583_erl:load_specification(code:priv_dir(iso8583_echo_server)++"/"++Spec_path_interface),
		{ok, _} = ranch:start_listener(Name_interface,
		ranch_tcp,#{socket_opts => [{port, Port_interface}],max_connections =>Limit_interface},
		iso8583_echo_server_sock_serv, [Byte_header_size_interface,Specification])		
	end,Interfaces).


test()->
    {ok,Spec_config_path} = application:get_env(iso8583_echo_server,client_spec_path),
	{ok, Bheader} = application:get_env(iso8583_echo_server,client_byte_header_size), 
    {ok,Host} = application:get_env(iso8583_echo_server,client_server_address),  
    {ok, Port} = application:get_env(iso8583_echo_server,client_port),   
    Spec_path = code:priv_dir(iso8583_echo_server)++"/"++Spec_config_path,
    io:format("~nspec path is ~p",[Spec_path]),
    Specification = iso8583_erl:load_specification(Spec_path),
    Map_send_list = iso8583_erl:set_field_list([{mti,<<"0200">>},{2,<<"12345">>},{3,<<"201234">>},{4,<<"450">>},{5,<<"5000">>},{11,<<"12143">>},{12,get_date_send_data()},{22,<<"A1239022">>},{39,<<"000">>},{41,<<"lashibi">>},{43,<<"ELFOODS ">>},{97,<<"qwer2134">>},{102,<<"121222">>},{103,<<"12109853">>}]),
    Iso_Response = [Mti,Bitmap_final_bit,Fields_list] = iso8583_erl:pack(Map_send_list,Specification),
	Final_size = iso8583_erl:get_size_send(Iso_Response,Bheader),
	Final_socket_send = [Final_size,Iso_Response],
    io:format("~n sending message ~p",[Map_send_list]),	 
    case gen_tcp:connect(Host, Port, [list, {active, once}]) of
        {ok, Socket} ->
			ok = gen_tcp:send(Socket,Final_socket_send),
			ok = gen_tcp:close(Socket);
		{error, Error} ->
            error_logger:format("Connection failed: ~ts~n", [inet:format_error(Error)])
			
    end.


get_date_send_data()->
	{{Yr,Mn,Dy},{Hr,Min,Se}}  = calendar:local_time(),
    Yr_send = string:right(erlang:integer_to_list(Yr),2,$0),
    Mn_send = string:right(erlang:integer_to_list(Mn),2,$0),
    Dy_send = string:right(erlang:integer_to_list(Dy),2,$0),
    Hr_send = string:right(erlang:integer_to_list(Hr),2,$0),
    Min_send = string:right(erlang:integer_to_list(Min),2,$0),
    Se_send = string:right(erlang:integer_to_list(Se),2,$0),
	erlang:list_to_binary([Yr_send,Mn_send,Dy_send,Hr_send,Mn_send,Se_send]).
