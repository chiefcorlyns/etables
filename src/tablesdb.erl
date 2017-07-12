-module(tablesdb).
-compile(export_all).

-include("records.hrl").
-include_lib("stdlib/include/qlc.hrl").

reset() ->
    mnesia:stop(),
    mnesia:delete_schema([node()]),
    mnesia:create_schema([node()]),
    mnesia:start(),

    mnesia:create_table(table, [{disc_copies, [node()]}, {attributes, record_info(fields, table)}]),
    mnesia:create_table(project, [{disc_copies, [node()]}, {attributes, record_info(fields, project)}]),
    mnesia:create_table(user, [{disc_copies, [node()]}, {attributes, record_info(fields, user)}]),
    mnesia:create_table(row, [{disc_copies, [node()]}, {attributes, record_info(fields, row)}]),
    mnesia:create_table(counter, [{disc_copies, [node()]}, {attributes, record_info(fields, counter)}]),
    mnesia:create_table(painting,
        [ {disc_copies, [node()] },
             {attributes,      
                record_info(fields,painting)} ]).
find(Q) ->
    F = fun() ->
            qlc:e(Q)
    end,
    transaction(F).

count(Q) ->
    F = fun() ->
            length(qlc:e(Q))
    end,
    transaction(F).

limit(Table, Offset, Number) -> 
    TH = qlc:keysort(2, mnesia:table(Table)), 
    QH = qlc:q([Q || Q <- TH]), 
    QC = qlc:cursor(QH), 
    %% Drop initial resuls. Handling of Offset =:= 0 not shown. 
    qlc:next_answers(QC, Offset - 1), 
    Results = qlc:next_answers(QC, Number), 
    qlc:delete_cursor(QC), 
    Results.

transaction(F) ->
    case mnesia:transaction(F) of
        {atomic, Result} ->
            Result;
        {aborted, _Reason} ->
            []
    end.

new_id(Key) ->
    mnesia:dirty_update_counter({counter, Key}, 1).

read(Oid) ->
    F = fun() ->
            mnesia:read(Oid)
    end,
    transaction(F).

read_all(Table) ->
    Q = qlc:q([X || X <- mnesia:table(Table)]),
    find(Q). 

write(Rec) ->
    F = fun() ->
            mnesia:write(Rec)
    end,
    mnesia:transaction(F).

delete(Oid) ->
    F = fun() ->
            mnesia:delete(Oid)
    end,
    mnesia:transaction(F).

selectIndex( Index) ->
    Fun = 
        fun() ->
            mnesia:read({project, Index})
        end,
    {atomic, [Row]}=mnesia:transaction(Fun),
    io:format(" ~p ~p ~n ", [Row#project.username, Row#project.password] ).

select_all() -> 
    mnesia:transaction( 
    fun() ->
        qlc:eval( qlc:q(
            [ X || X <- mnesia:table(painting) ] 
        )) 
    end ).

    insertData( Index, Artist, Title) ->
    Fun = fun() ->
         mnesia:write(
         #painting{ index=Index,
                   artist=Artist, 
                        title=Title    } )
               end,
         mnesia:transaction(Fun).



