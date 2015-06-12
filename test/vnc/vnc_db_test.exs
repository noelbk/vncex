defmodule Vnc.Db.Test do 
	use ExUnit.Case, async: true

	test "vnc_db events" do
		db_path = "test/vnc_db_test.db"
		File.rm(db_path)
		{:ok, db} = Vnc.Db.start_link(db_path)

		Vnc.Db.event_insert(db, %Vnc.Event.Keyframe{time: 101})
		Vnc.Db.event_insert(db, %Vnc.Event.Tile{time: 102})
		Vnc.Db.event_insert(db, %Vnc.Event.Tile{time: 103})
		{:ok, e201} = Vnc.Db.event_insert(db, %Vnc.Event.Keyframe{time: 201})
		{:ok, e202} = Vnc.Db.event_insert(db, %Vnc.Event.Tile{time: 202})
		{:ok, e203} = Vnc.Db.event_insert(db, %Vnc.Event.Tile{time: 203})
		{:ok, e204} = Vnc.Db.event_insert(db, %Vnc.Event.Tile{time: 204})
		{:ok, rs} = Vnc.Db.event_play(db, 203)
		{:vnc_event, ^e201} = Vnc.Db.event_next(db, rs)
		{:vnc_event, ^e202} = Vnc.Db.event_next(db, rs)
		{:vnc_event, ^e203} = Vnc.Db.event_next(db, rs)
		{:vnc_event, ^e204} = Vnc.Db.event_next(db, rs)
		:end = Vnc.Db.event_next(db, rs)
	end
end	
