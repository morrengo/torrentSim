-module(torrentCom).
-compile(export_all).
-record(file, {file_name, file_hash, chunks, length}).
-record(chunk, {chunk_number, data}).
-record(wishList, {file_name, chunks_numbers}).

-include_lib("wx/include/wx.hrl").
-include_lib("wx/src/wxe.hrl").

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

client(MyClients,Data,Self,Pid) ->
	Pid!{fileFormat:filesToHas(Data),Self,my_files},
	io:format("~p my files: ~p ~n",[self(),Data]),
	timer:sleep(500),
	receive
		{NewClients, new_clients} ->
			client(addClients(NewClients,MyClients),Data,Self,Pid);
		{File_name, Chunk, gift} ->
			io:format("~p: received: ~p ~p ~n" ,[self(),File_name,Chunk#chunk.chunk_number]),
			client(MyClients,receiveGift(Data, File_name, Chunk),Self,Pid);
		{From, HisWishes, send_me_data} ->
			io:format("~p: i will send ~n",[self()]),
			sendData(From, HisWishes, Data),
			client(MyClients,Data,Self,Pid);
    exit_process ->
      io:format("~p KLIENT KOŃCZY DZIAŁANIE~n",[self()]),
      exit(self(),kill)
	after 1000 ->
		io:format("~p filesToWants: ~p ~n",[self(),fileFormat:filesToWants(Data)]),
		requestAll(MyClients, fileFormat:filesToWants(Data)),
		client(MyClients,Data,Self,Pid)
	end.



main() ->
	ClientsNumber = 3,
	FilesLength = [6,4,7],
	FileNames = ["binary","dare","viruses"],

	Pid0 = spawn(?MODULE,make_window,[ClientsNumber,FilesLength,FileNames,self()]),
	Pid1 = spawn(?MODULE,client,[[],
		[{file,"test",0,[{chunk,0,"b"},{chunk,3,"a"}],6},
		 {file,"dare",0,[{chunk,0,"d"},{chunk,3,"e"}],4},
		 {file,"viruses",0,[{chunk,1,"i"},{chunk,3,"u"},{chunk,6,"s"}],7}],
		1,Pid0]),
	Pid2 = spawn(?MODULE,client,[[],
		[{file,"test",0,[{chunk,2,"n"},{chunk,4,"r"}],6},
			{file,"dare",0,[{chunk,1,"a"}],4},
			{file,"viruses",0,[{chunk,4,"e"}],7}],
			2,Pid0]),
	Pid3 = spawn(?MODULE,client,[[],
		[{file,"test",0,[{chunk,1,"i"},{chunk,5,"y"}],6},
		{file,"dare",0,[{chunk,2,"r"}],4},
			{file,"viruses",0,[{chunk,0,"v"},{chunk,2,"r"},{chunk,5,"e"}],7}],
		3,Pid0]),

	Pid1!{[Pid2,Pid3],new_clients},
	Pid2!{[Pid1,Pid3],new_clients},
	Pid3!{[Pid1,Pid2],new_clients},

  receive
    close_program ->
      shutdownClients([Pid1,Pid2,Pid3]),
      timer:sleep(2000),
      io:format("~p KOŃCZĘ DZIAŁANIE PROGRAMU~n",[self()])
  end.

shutdownClients([]) -> ok;
shutdownClients([H|Rest]) ->
  H ! exit_process,
  shutdownClients(Rest).

make_window(Length,Columns,FileNames,ParentPID) ->
	Server = wx:new(),
	Frame = wxFrame:new(Server, -1, "Torrent simulation", [{size,{800, 600}}]),
	Panel  = wxPanel:new(Frame),

	MainSizer = wxBoxSizer:new(?wxVERTICAL),
	Sizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel,
		[{label, "Downloads"}]),

	Grids = create_grids(Panel,Length,Columns,FileNames),

	Options = [{flag, ?wxEXPAND}, {proportion, 1}],

	wx:foreach(fun(X) -> wxSizer:add(Sizer,X,Options) end, Grids),

	wxSizer:add(MainSizer, Sizer, Options),

	wxPanel:setSizer(Panel, MainSizer),

	wxFrame:show(Frame),

	Env = wx:get_env(),

	Pids = lists:map(fun(X) -> spawn(?MODULE,initLoop,[Frame,lists:nth(X,Grids),Length,lists:nth(X,Columns),Env,self()]) end, lists:seq(1,length(Grids))),

	manager(Frame,Grids,Pids,0,ParentPID).

manager(_,_,PidList,Counter,ParentPID) when Counter==length(PidList) ->
  io:format("~p : MANAGER ZABITY~n", [self()]),
  ParentPID ! close_program,
  exit(self(),kill);
manager(Frame,Grids,PidList,Counter,ParentPID) ->
	receive
		{ClientFiles,Client,my_files} ->
      wx:foreach(fun({Pid,File}) -> Pid!{File,Client,file} end,lists:zip(PidList,ClientFiles)),
			wxFrame:refresh(Frame),
			wxFrame:show(Frame);
    funeral_letter ->
      manager(Frame,Grids,PidList,Counter+1,ParentPID)
	end,
	manager(Frame,Grids,PidList,Counter,ParentPID).

initLoop(Frame,Grid,RowsLength,ColumnsLength,Env,ParentPID) ->
	wx:set_env(Env),
	loop(Frame,Grid,RowsLength,ColumnsLength,ParentPID).

loop(Frame,Grid,RowsLength,ColumnsLength,ParentPID) ->
	receive
		{File,Client,file} ->
			iterate(Grid,Client-1,File#wishList.chunks_numbers)
	end,
	killLoop(checkGridComplete(Grid,RowsLength,ColumnsLength),ParentPID),
	loop(Frame,Grid,RowsLength,ColumnsLength,ParentPID).

create_grids(Panel,Length,Columns,FileNames) ->
	create_grids(Panel,Length,Columns,FileNames,0,[]).

create_grids(Panel,Length,[C|Rest],[FileName|RestNames],Counter,Result) ->
	create_grids(Panel,Length,Rest,RestNames,Counter+1,Result ++ [create_grid(Panel,Length,C,FileName,Counter)]);

create_grids(_,_,[],[],_,Result) ->
	Result.

create_grid(Panel,Length,ColumnsLength,FileName,Counter) ->
	Grid = wxGrid:new(Panel, Counter, []),
	wxGrid:createGrid(Grid, Length, ColumnsLength),

	Fun =
		fun(Row) ->
			wx:foreach(fun(X) -> wxGrid:setCellBackgroundColour(Grid,Row,X,?wxRED) end, lists:seq(0,ColumnsLength-1))
		end,

	wx:foreach(Fun, lists:seq(0,Length-1)),

	FunCol =
		fun(Col) ->
			Char = lists:nth(Col+1,FileName),
			wxGrid:setColLabelValue(Grid,Col,binary_to_list(<<Char>>))
		end,


	wx:foreach(FunCol,lists:seq(0,length(FileName)-1)),

	wxGrid:setColSize(Grid, 2, 100),
	Grid.




modifyGrid(Grid,Row,Chunk) ->
	wxGrid:setCellBackgroundColour(Grid,Row,Chunk,?wxGREEN),
	Grid.

iterate(Grid,_,[]) -> Grid;
iterate(Grid,Row,[H|Rest]) ->
	Grid = modifyGrid(Grid,Row,H),
	iterate(Grid,Row,Rest).

checkCellColorGreen(Grid,Row,Col) ->
  Color = wxGrid:getCellBackgroundColour(Grid,Row,Col),
  Green = ?wxGREEN,
  if
    Color==Green -> true;
    true -> false
  end.

checkGridComplete(Grid,Rows,Cols) ->
  RowsList = lists:seq(0,Rows-1),
  ColsList = lists:seq(0,Cols-1),
  CellsList = [{X,Y} || X <- RowsList, Y <- ColsList],
  lists:all(fun({X,Y}) -> checkCellColorGreen(Grid,X,Y) end,CellsList).

killLoop(Kill,ParentPID) ->
  case Kill of
    true ->
      ParentPID ! funeral_letter,
      exit(self(),kill);
    false -> void
  end.