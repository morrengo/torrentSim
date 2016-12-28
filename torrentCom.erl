-module(torrentCom).
-compile(export_all).

-record(client, {pid,has,wants}).
-record(wishes, {has,wants}).

requestAll([],_) -> 0;
requestAll([MyClient|Rest],MyWishes) ->
	MyClient!{self(),MyWishes,send_me_data},
	requestAll(Rest,MyWishes).

receiveGift(Data, File_name, Chunk) ->
	case fileFormat:findFile(Data, File_name) of
    	[] -> Data;
        _Else -> fileFormat:addChunk(Data, File_name, Chunk)
    end.

sendData(To, HisWishes, Data) ->
	lists:foreach(fun(X) -> To!{X,gift} end,Data).

addClients(NewClients,MyClients) ->
	MyClients ++ (NewClients -- MyClients).

client(MyClients,Data) ->
	requestAll(MyClients, fileFormat:filesToWants(Data)),
	timer:sleep(500),
	io:format(": ~p ~n",[Data]),
	receive
		{NewClients, new_clients} ->
			client(addClients(NewClients,MyClients),Data);
		{File_name, Chunk, gift} ->
			client(MyClients,receiveGift(Data, File_name, Chunk));
		{From, HisWishes, send_me_data} ->
			sendData(From, HisWishes, Data),
			client(MyClients,Data)
	end.

main() ->
	Pid1 = spawn(?MODULE,client,[[],[1,2,3,4,5,6]]),
	Pid2 = spawn(?MODULE,client,[[],[11,21,31,41,51,61]]),
	Pid1!{[Pid2],new_clients},
	Pid2!{[Pid1],new_clients}.