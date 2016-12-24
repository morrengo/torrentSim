-module(torrentCom).
%-export([main/0]).
-compile(export_all).

requestAll([]) -> 0;
requestAll([Dest|Rest]) ->
	Dest!{self(),send_me_data},
	requestAll(Rest).

receiveGift(Data,Gift) ->
	case lists:member(Gift,Data) of
    	true -> Data;
        false -> [Gift|Data]
    end.

sendData(To,Data) ->
	lists:foreach(fun(X) -> To!{X,gift} end,Data).

addClients(NewClients,MyClients) ->
	MyClients ++ (NewClients -- MyClients).

client(MyClients,Data) ->
	requestAll(MyClients),
	timer:sleep(500),
	io:format(": ~p ~n",[Data]),
	receive
		{NewClients,new_clients} ->
			client(addClients(NewClients,MyClients),Data);
		{Gift,gift} ->
			client(MyClients,receiveGift(Data,Gift));
		{From,send_me_data} ->
			sendData(From,Data),
			client(MyClients,Data)
	end.

main() ->
	Pid1 = spawn(?MODULE,client,[[],[1,2,3,4,5,6]]),
	Pid2 = spawn(?MODULE,client,[[],[11,21,31,41,51,61]]),
	Pid1!{[Pid2],new_clients},
	Pid2!{[Pid1],new_clients}.