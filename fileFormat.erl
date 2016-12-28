-module(fileFormat).
-export([formatFile/3,filesToHas/1,filesToWants/1,addChunk/3,findFile/2]).

-record(file, {file_name, file_hash, chunks, length}).
-record(chunk, {chunk_number, data}).
-record(wishList, {file_name, chunks_numbers}).

%extracting "wants" and "has" from files

filesToHas(Files) -> filesToHasImp(Files,[]).

filesToHasImp([File|Rest], Result) ->
	filesToHasImp(Rest, Result ++ [fileToHas(File)]);
filesToHasImp([], Result) -> Result.

filesToWants(Files) -> filesToWantsImp(Files,[]).

filesToWantsImp([File|Rest], Result) ->
	filesToWantsImp(Rest, Result ++ [fileToWants(File)]);
filesToWantsImp([], Result) -> Result.

fileToHas(File) ->
	#wishList{	file_name = File#file.file_name,
				chunks_numbers = lists:map(fun(Chunk) 
					-> Chunk#chunk.chunk_number end, File#file.chunks)}.

fileToWants(File) ->
	#wishList{	file_name = File#file.file_name,
				chunks_numbers = lists:seq(0, File#file.length) 
				-- lists:map(fun(Chunk) 
					-> Chunk#chunk.chunk_number end, File#file.chunks)}.

%creating "file" record from data

formatFile(Name,FileData,ChunkSize) ->
	#file{ 	file_name = Name,
			file_hash = 0,
			chunks = chunkify(FileData,ChunkSize),
			length = length(FileData) div ChunkSize + 1}.

chunkify(Data,ChunkSize) -> lists:reverse(chunkifyImp(Data,[],0,ChunkSize)).

chunkifyImp([],Result,_,_) -> Result;
chunkifyImp(Data,Result,CurrID,ChunkSize) ->
	DataForChunk = takeSome(Data,ChunkSize),
	Chunk = #chunk{chunk_number = CurrID, data = DataForChunk},
	chunkifyImp(removeSome(Data,ChunkSize),[Chunk|Result],CurrID+1,ChunkSize).
	
takeSome(Data,ChunkSize) -> takeSomeImp(Data,ChunkSize,[],0).
removeSome(Data,ChunkSize) -> removeSomeImp(Data,ChunkSize,0).

takeSomeImp([H|Data],ChunkSize,Result,Count) ->
	if (Count >= ChunkSize) ->
		lists:reverse(Result);
	true ->
		takeSomeImp(Data,ChunkSize,[H|Result],Count+1)
	end;
takeSomeImp([],_,Result,_) ->
	lists:reverse(Result).

removeSomeImp([H|Data],ChunkSize,Count) ->
	if (Count >= ChunkSize) ->
		[H|Data];
	true ->
		removeSomeImp(Data,ChunkSize,Count+1)
	end;
removeSomeImp([],_,_) ->
	[].

%editing file

addChunk(Files, File_name, Chunk) -> addChunk(Files, File_name, Chunk, []).

addChunk([],_,_,Result) -> Result;
addChunk([File|Rest], File_name, Chunk, Result) ->
	if (File#file.file_name == File_name) ->
		addChunk(Rest, [], [], Result ++
			[#file{ 
				file_name = File#file.file_name,
				file_hash = File#file.file_hash,
				chunks = insertChunk(File#file.chunks, Chunk),
				length = File#file.length }
			]);
	true ->
		addChunk(Rest, File_name, Chunk, Result ++ File)
	end.


insertChunk(Chunks, ChunkIn) -> insertChunk(Chunks, ChunkIn, []).
insertChunk([Chunk1|Rest], ChunkIn, []) ->
	Num = ChunkIn#chunk.chunk_number,
	if (Num < Chunk1#chunk.chunk_number) ->
		insertChunk(Rest, [], [ChunkIn,Chunk1]);
	true ->
		insertChunk(Rest, ChunkIn, [Chunk1])
	end;
insertChunk([], _, Result) -> Result;
insertChunk([Chunk1|Rest], [], Result) ->
	insertChunk(Rest, [], Result ++ [Chunk1]);
insertChunk([Chunk1], ChunkIn, Result) ->
	Num = ChunkIn#chunk.chunk_number,
	if (Num > Chunk1#chunk.chunk_number) ->
		insertChunk([], [], Result ++ [Chunk1,ChunkIn]);
	true ->
		insertChunk([], [], Result ++ [ChunkIn,Chunk1])
	end;
insertChunk([Chunk1, Chunk2|Rest], ChunkIn, Result) ->
	Num = ChunkIn#chunk.chunk_number,
	if (Num > Chunk1#chunk.chunk_number) and
	   (Num < Chunk2#chunk.chunk_number) ->
		insertChunk(Rest, [], Result ++ [Chunk1,ChunkIn,Chunk2]);
	true ->
		insertChunk([Chunk2|Rest], ChunkIn, Result ++ [Chunk1])
	end.

findFile([File|Rest], File_name) ->
	if (File#file.file_name == File_name) ->
		File;
	true ->
		findFile(Rest, File_name)
	end;
findFile([], _) -> [].

