-module(torrentFormat).
-export([formatFile/3]).

-record(file, {file_name, file_hash, chunks}).
-record(chunk, {chunk_number, data}).

formatFile(Name,FileData,ChunkSize) ->
	#file{	file_name = Name,
			file_hash = 0,
			chunks = chunkify(FileData,ChunkSize)}.

chunkify(Data,ChunkSize) -> lists:reverse(chunkifyImp(Data,[],0,ChunkSize)).

chunkifyImp([],Res,_,_) -> Res;
chunkifyImp(Data,Res,CurrID,ChunkSize) ->
	DataForChunk = takeSome(Data,ChunkSize),
	Chunk = #chunk{chunk_number = CurrID, data = DataForChunk},
	chunkifyImp(removeSome(Data,ChunkSize),[Chunk|Res],CurrID+1,ChunkSize).
	
takeSome(Data,ChunkSize) -> takeSomeImp(Data,ChunkSize,[],0).
removeSome(Data,ChunkSize) -> removeSomeImp(Data,ChunkSize,0).

takeSomeImp([H|Data],ChunkSize,Res,Count) ->
	if (Count >= ChunkSize) ->
		lists:reverse(Res);
	true ->
		takeSomeImp(Data,ChunkSize,[H|Res],Count+1)
	end;
takeSomeImp([],_,Res,_) ->
	lists:reverse(Res).

removeSomeImp([H|Data],ChunkSize,Count) ->
	if (Count >= ChunkSize) ->
		[H|Data];
	true ->
		removeSomeImp(Data,ChunkSize,Count+1)
	end;
removeSomeImp([],_,_) ->
	[].
