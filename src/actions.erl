%% Author: ildus
%% Created: 20.04.2011
%% Description: TODO: Add description to actions
-module(actions).

%%
%% Include files
%%

-include_lib("stdlib/include/qlc.hrl").
-include("records.hrl").

%%
%% Exported Functions
%%
-export([new_table/1, tables_list/1, delete_table/1, add_row/1, table_rows/1, edit_table/1, edit_row/1]).
-export([authenticate/1]).

%%
%% API Functions
%%

new_table(S) ->
    change_table(S, tablesdb:new_id(tables)).

edit_table(S) ->
    change_table(S, struct:get_value(<<"table_id">>, S)).
    
change_table(S, Id) when is_integer(Id) -> 
    Name = struct:get_value(<<"table_name">>, S),
    Columns = case struct:get_value(<<"columns">>, S) of
                  undefined -> [];
                  List when is_list(List) -> parse_columns(List)
              end,
    {atomic, ok} = tablesdb:write(#table{id = Id, name = Name, columns = Columns}),
    S1 = struct:set_value(<<"id">>, Id, S),
    S1.
    
tables_list(S) ->
    Tables = tablesdb:read_all(table),
    lists:map(fun(F) -> {struct, [
                                  {<<"id">>, F#table.id}, 
                                  {<<"name">>, F#table.name},
                                  {<<"columns">>, reparse_columns(F#table.columns)}]} 
              end, Tables).

table_rows(S) ->
    TableId = struct:get_value(<<"table_id">>, S),
    Q = qlc:q([X || X <- mnesia:table(row), X#row.table_id == TableId]),
    Rows = tablesdb:find(Q),
    lists:map(fun(R) -> {struct, [
                                  {<<"id">>, R#row.id},
                                  {<<"table_id">>, R#row.table_id},
                                  {<<"data">>, R#row.data}]}
              end, Rows).

delete_table(S) ->
    Id = struct:get_value(<<"table_id">>, S),
    {atomic, ok} = tablesdb:delete({table, Id}),
    struct:set_value(<<"deleted">>, <<"ok">>, S).

add_row(S) ->
    change_row(S, tablesdb:new_id(rows)).

edit_row(S) ->
    Id = struct:get_value(<<"row_id">>, S),
    change_row(S, Id).

change_row(S, Id) when is_integer(Id) ->
    TableId = struct:get_value(<<"table_id">>, S),
    {struct, RowData} = S,
    RowData1 = repair_column_ids(RowData),
    {atomic, ok} = tablesdb:write(#row{id = Id, table_id = TableId, data = RowData1}),
    struct:set_value(<<"row_id">>, Id, S).

authenticate(S) ->
    Username = binary_to_list(struct:get_value(<<"username">>, S)),
    Password = binary_to_list(struct:get_value(<<"password">>, S)),
    Q = qlc:q([X || X <- mnesia:table(user), X#user.username == Username]),
    case tablesdb:find(Q) of
        [User|Other] ->
            if User#user.password == Password -> User;
               true -> undefined
            end;
        [] -> undefined
    end.

%%
%% Local Functions
%%

parse_columns(Columns) ->
    parse_columns(Columns, []).

parse_columns([], Res) ->
    io:format("~p~n", [Res]),
    Res;
parse_columns([Col|Other], Res) ->
    [Name, Type, IsFilter, Id] = Col,
    ColumnId = if Id == 0 -> tablesdb:new_id(columns);
                  is_integer(Id) -> Id;
                  is_list(Id) -> list_to_integer(Id)
               end,
    ColType = list_to_atom(binary_to_list(Type)),
    parse_columns(Other, [{ColType, Name, IsFilter, ColumnId}|Res]).

reparse_columns(Columns) ->
    reparse_columns(Columns, {struct, []}).

reparse_columns([], S) ->
    S;
reparse_columns([Col|Other], S) ->
    {ColTypeA, Name, IsFilter, ColumnId} = Col,
    ColKey = list_to_binary(integer_to_list(ColumnId)),
    ColType = list_to_binary(atom_to_list(ColTypeA)),
    {struct, Res} = S,
    reparse_columns(Other, {struct, [{ColKey, {struct, [{<<"id">>, ColKey},
                                                        {<<"name">>, Name}, 
                                                        {<<"type">>, ColType},
                                                        {<<"is_filter">>, IsFilter}]
                                              }
                                     }|Res]
                           }).

repair_column_ids([{BinaryId, Value}|Row], Res) ->
    try list_to_integer(binary_to_list(BinaryId)) of
        Id -> repair_column_ids(Row, [{Id, Value}|Res])
    catch
        _:_ -> repair_column_ids(Row, Res)
    end;
    
repair_column_ids([], Res) ->
    Res.

repair_column_ids(Val) when is_list(Val) ->
    repair_column_ids(Val, []).