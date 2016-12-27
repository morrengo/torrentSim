-module(torrentFormat).
-export([formatFile/3,fileToHas/1]).

-record(file, {file_name, file_hash, chunks, length}).
-record(chunk, {chunk_number, data}).
-record(wishList, {file_name, chunks_numbers}).

fileToHas(File) ->
	#wishList{	file_name = File#file.file_name,
				chunks_numbers = lists:map(fun(Chunk) 
					-> Chunk#chunk.chunk_number end, File#file.chunks)}.



formatFile(Name,FileData,ChunkSize) ->
	#file{ 	file_name = Name,
			file_hash = 0,
			chunks = chunkify(FileData,ChunkSize),
			length = length(FileData) div ChunkSize + 1}.

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
