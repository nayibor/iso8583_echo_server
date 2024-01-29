%%%-------------------------------------------------------------------
%% @doc iso8583_echo_server public API
%% @end
%%%-------------------------------------------------------------------

-module(iso8583_echo_server_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    iso8583_echo_server_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
