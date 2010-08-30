%%
%% Licensed to the Apache Software Foundation (ASF) under one
%% or more contributor license agreements. See the NOTICE file
%% distributed with this work for additional information
%% regarding copyright ownership. The ASF licenses this file
%% to you under the Apache License, Version 2.0 (the
%% "License"); you may not use this file except in compliance
%% with the License. You may obtain a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied. See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%

-module(thrift_client).

%% API
-export([new/2, call/3, send_call/3, close/1]).

-include("thrift_constants.hrl").
-include("thrift_protocol.hrl").

-record(tclient, {service, protocol, seqid}).


new(Protocol, Service)
  when is_atom(Service) ->
    {ok, #tclient{protocol = Protocol,
                  service = Service,
                  seqid = 0}}.

-spec call(#tclient{}, atom(), list()) -> {#tclient{}, {ok, term()} | {error, term()}}.
call(Client = #tclient{}, Function, Args)
  when is_atom(Function), is_list(Args) ->
    case send_function_call(Client, Function, Args) of
        {Client1, ok} ->
            receive_function_result(Client1, Function);
        Else ->
            Else
    end.


%% Sends a function call but does not read the result. This is useful
%% if you're trying to log non-oneway function calls to write-only
%% transports like thrift_disk_log_transport.
-spec send_call(#tclient{}, atom(), list()) -> {#tclient{}, ok}.
send_call(Client = #tclient{}, Function, Args)
  when is_atom(Function), is_list(Args) ->
    send_function_call(Client, Function, Args).

-spec close(#tclient{}) -> ok.
close(#tclient{protocol=Protocol}) ->
    thrift_protocol:close_transport(Protocol).


%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
-spec send_function_call(#tclient{}, atom(), list()) -> {#tclient{}, ok | {error, term()}}.
send_function_call(Client = #tclient{protocol = Proto0,
                                     service  = Service,
                                     seqid    = SeqId},
                   Function,
                   Args) ->
    Params = Service:function_info(Function, params_type),
    case Params of
        no_function ->
            {Client, {error, {no_function, Function}}};
        {struct, PList} when length(PList) =/= length(Args) ->
            {Client, {error, {bad_args, Function, Args}}};
        {struct, _PList} ->
            Begin = #protocol_message_begin{name = atom_to_list(Function),
                                            type = ?tMessageType_CALL,
                                            seqid = SeqId},
            {Proto1, ok} = thrift_protocol:write(Proto0, Begin),
            {Proto2, ok} = thrift_protocol:write(Proto1, {Params, list_to_tuple([Function | Args])}),
            {Proto3, ok} = thrift_protocol:write(Proto2, message_end),
            {Proto4, ok} = thrift_protocol:flush_transport(Proto3),
            {Client#tclient{protocol = Proto4}, ok}
    end.

-spec receive_function_result(#tclient{}, atom()) -> {#tclient{}, {ok, term()} | {error, term()}}.
receive_function_result(Client = #tclient{service = Service}, Function) ->
    ResultType = Service:function_info(Function, reply_type),
    read_result(Client, Function, ResultType).

read_result(Client, _Function, oneway_void) ->
    {Client, {ok, ok}};

read_result(Client = #tclient{protocol = Proto,
                              seqid    = SeqId},
            Function,
            ReplyType) ->
    case thrift_protocol:read(Proto, message_begin) of
        #protocol_message_begin{seqid = RetSeqId} when RetSeqId =/= SeqId ->
            {Client, {error, {bad_seq_id, SeqId}}};

        #protocol_message_begin{type = ?tMessageType_EXCEPTION} ->
            handle_application_exception(Client);

        #protocol_message_begin{type = ?tMessageType_REPLY} ->
            handle_reply(Client, Function, ReplyType)
    end.


handle_reply(Client = #tclient{protocol = Proto,
                               service = Service},
             Function,
             ReplyType) ->
    {struct, ExceptionFields} = Service:function_info(Function, exceptions),
    ReplyStructDef = {struct, [{0, ReplyType}] ++ ExceptionFields},
    {ok, Reply} = thrift_protocol:read(Proto, ReplyStructDef),
    ok = thrift_protocol:read(Proto, message_end),
    ReplyList = tuple_to_list(Reply),
    true = length(ReplyList) == length(ExceptionFields) + 1,
    ExceptionVals = tl(ReplyList),
    Thrown = [X || X <- ExceptionVals,
                   X =/= undefined],
    case Thrown of
        [] when ReplyType == {struct, []} ->
            {Client, {ok, ok}};
        [] ->
            {Client, {ok, hd(ReplyList)}};
        [Exception] ->
            throw({Client, {exception, Exception}})
    end.

handle_application_exception(Client = #tclient{protocol = Proto}) ->
    {ok, Exception} =
        thrift_protocol:read(Proto, ?TApplicationException_Structure),
    ok = thrift_protocol:read(Proto, message_end),
    XRecord = list_to_tuple(
                ['TApplicationException' | tuple_to_list(Exception)]),
    error_logger:error_msg("X: ~p~n", [XRecord]),
    true = is_record(XRecord, 'TApplicationException'),
    throw({Client, {exception, XRecord}}).
