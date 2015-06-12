defmodule Vnc.Db.Test do 
	use ExUnit.Case, async: true

	test "vnc_db events" do
		db_path = 'test/vnc_db_test.db'
		File.rm(db_path)
		{:ok, db, 1} = Vnc.Db.open(db_path)

		{:ok, _e101} = Vnc.Db.event_insert(db, %Vnc.Event.Keyframe{time: 101})
		{:ok, _e102} = Vnc.Db.event_insert(db, %Vnc.Event.Tile{time: 102})
		{:ok, _e103} = Vnc.Db.event_insert(db, %Vnc.Event.Tile{time: 103})
		{:ok, e201} = Vnc.Db.event_insert(db, %Vnc.Event.Keyframe{time: 201})
		{:ok, e202} = Vnc.Db.event_insert(db, %Vnc.Event.Tile{time: 202})
		{:ok, e203} = Vnc.Db.event_insert(db, %Vnc.Event.Tile{time: 203})
		{:ok, e204} = Vnc.Db.event_insert(db, %Vnc.Event.Tile{time: 204})
		{:ok, rs} = Vnc.Db.event_play(db, 203)
		{:vnc_event, ^e201} = Vnc.Db.event_next(rs)
		{:vnc_event, ^e202} = Vnc.Db.event_next(rs)
		{:vnc_event, ^e203} = Vnc.Db.event_next(rs)
		{:vnc_event, ^e204} = Vnc.Db.event_next(rs)
		:end = Vnc.Db.event_next(rs)

		:ok = :esqlite3.close(db)
	end
end	
