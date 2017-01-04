-module(fileFormat).
%-export([formatFile/3,filesToHas/1,filesToWants/1,addChunk/3,findFile/2]).
-compile(export_all).
-record(file, {file_name, file_hash, chunks, length}).
-record(chunk, {chunk_number, data}).
-record(wishList, {file_name, chunks_numbers}).

%extracting "wants" and "has" from files

filesToHas(Files) -> filesToHas(Files,[]).

filesToHas([File|Rest], Result) ->
	filesToHas(Rest, Result ++ [fileToHas(File)]);
filesToHas([], Result) -> Result.

filesToWants(Files) -> filesToWants(Files,[]).

filesToWants([File|Rest], Result) ->
	filesToWants(Rest, Result ++ [fileToWants(File)]);
filesToWants([], Result) -> Result.

fileToHas(File) ->
	#wishList{	file_name = File#file.file_name,
				chunks_numbers = lists:map(fun(Chunk) 
					-> Chunk#chunk.chunk_number end, File#file.chunks)}.

fileToWants(File) ->
	#wishList{	file_name = File#file.file_name,
				chunks_numbers = lists:seq(0, File#file.length-1) 
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
		addChunk(Rest, File_name, Chunk, Result ++ [File])
	end.


insertChunk(Chunks, ChunkIn) -> insertChunk(Chunks, ChunkIn, []).

insertChunk([Chunk|Rest], ChunkIn, Result) ->
	if(Chunk#chunk.chunk_number == ChunkIn#chunk.chunk_number) ->
		Result ++ [Chunk] ++ Rest;
	(Chunk#chunk.chunk_number > ChunkIn#chunk.chunk_number) ->
		Result ++ [ChunkIn,Chunk] ++ Rest;
	true ->
		insertChunk(Rest, ChunkIn, Result ++ [Chunk])
	end;
insertChunk([],ChunkIn,Result) -> 
	Result ++ [ChunkIn].


findFile([File|Rest], File_name) ->
	if (File#file.file_name == File_name) ->
		File;
	true ->
		findFile(Rest, File_name)
	end;
findFile([], _) -> [].

chunkIntersection(Files, Wishes) -> chunkIntersection(Files, Wishes, []).
chunkIntersection([File|Rest], Wishes, Result) -> 
	chunkIntersection(Rest, Wishes, findChunks(File,Wishes) ++ Result);
chunkIntersection([],_,Result) -> Result.

findChunks(File, Wishes) -> findChunks(File, Wishes,[]).
findChunks(File, [Wish|Rest], Result) ->
	if(Wish#wishList.file_name == File#file.file_name) ->
		findChunks(File, Rest,
		Result ++ [#file{file_name = File#file.file_name,
			  file_hash = File#file.file_hash,
			  chunks = intersect(File#file.chunks,Wish#wishList.chunks_numbers),
			  length = File#file.length}]);
	true ->
		findChunks(File,Rest, Result)
	end;
findChunks(_,[],Result) -> Result.

intersect(MyChunks, WantedChunks) -> intersect(MyChunks, WantedChunks, []).
intersect([MyChunk|Rest], WantedChunks, Result) ->
	case lists:member(MyChunk#chunk.chunk_number,WantedChunks) of
		true -> intersect(Rest, WantedChunks, Result ++ [MyChunk]);
		false -> intersect(Rest, WantedChunks, Result)
	end;
intersect([],_,Result) -> Result.