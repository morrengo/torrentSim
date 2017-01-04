-module(torrentCom).
-compile(export_all).
-record(file, {file_name, file_hash, chunks, length}).
-record(chunk, {chunk_number, data}).

requestAll([],_) -> 0;
requestAll([MyClient|Rest],MyWishes) ->
	%io:format("~p give me: ~p ~n",[self(),MyWishes]),
	MyClient!{self(),MyWishes,send_me_data},
	requestAll(Rest,MyWishes).

receiveGift(Data, File_name, Chunk) ->
	case fileFormat:findFile(Data, File_name) of
    	[] -> Data;
        _Else -> fileFormat:addChunk(Data, File_name, Chunk)
    end.

sendData(To, HisWishes, Data) ->
	sendFiles(fileFormat:chunkIntersection(Data, HisWishes), To).

sendFiles([File|Rest], To) ->
	sendChunks(File#file.chunks, File#file.file_name, To),
	sendFiles(Rest, To);
sendFiles([], _) -> 0.

sendChunks([Chunk|Rest], FileName, To) ->
	To!{FileName, Chunk, gift},
	sendChunks(Rest, FileName, To);
sendChunks([], _, _) -> 0.

addClients(NewClients,MyClients) ->
	MyClients ++ (NewClients -- MyClients).

client(MyClients,Data) ->
	io:format("~p my files: ~p ~n",[self(),Data]),
	timer:sleep(1000),
	receive
		{NewClients, new_clients} ->
			client(addClients(NewClients,MyClients),Data);
		{File_name, Chunk, gift} ->
			io:format("~p: received: ~p ~p ~n" ,[self(),File_name,Chunk#chunk.chunk_number]),
			client(MyClients,receiveGift(Data, File_name, Chunk));
		{From, HisWishes, send_me_data} ->
			%io:format("~p: i will send ~n",[self()]),
			sendData(From, HisWishes, Data),
			client(MyClients,Data)
		after 1000 ->
			requestAll(MyClients, fileFormat:filesToWants(Data)),
			client(MyClients,Data)
	end.

main() ->
	%Pid1 = spawn(?MODULE,client,[[],[fileFormat:formatFile("test","jeden dwa trzy cztery",2)]]),
	%Pid2 = spawn(?MODULE,client,[[],[{file,"test",0,[],11}]]),
	%Pid3 = spawn(?MODULE,client,[[],[{file,"test",0,[],11}]]),

	Pid1 = spawn(?MODULE,client,[[],[{file,"test",0,[{chunk,0,"d"},{chunk,3,"a"}],6}]]),
	Pid2 = spawn(?MODULE,client,[[],[{file,"test",0,[{chunk,2,"d"},{chunk,4,"a"}],6}]]),
	Pid3 = spawn(?MODULE,client,[[],[{file,"test",0,[{chunk,1,"d"},{chunk,5,"a"}],6}]]),

	Pid1!{[Pid2,Pid3],new_clients},
	Pid2!{[Pid1,Pid3],new_clients},
	Pid3!{[Pid1,Pid2],new_clients}.