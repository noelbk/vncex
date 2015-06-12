defmodule Vnc.Db do
	use GenServer

	def open(filename) do
		if is_binary(filename) do
			filename = String.to_char_list(filename)
		end
		{:ok, db} = :esqlite3.open(filename)
		{:ok, version} = db_upgrade(db)
		{:ok, db, version}
	end

	defp db_upgrade(db) do
    :ok = :esqlite3.exec("begin;", db)
		case :esqlite3.exec("create table version (version int not null)", db) do
			{:error, {:sqlite_error, 'table version already exists'}} -> 
				[{version}] = :esqlite3.q("select version from version", db)
				{:ok, version} = db_upgrade(version, db)
			:ok ->
				:ok = :esqlite3.exec("insert into version values (0)", db)
				{:ok, version} = db_upgrade(0, db)
		end
    :ok = :esqlite3.exec("commit;", db)
		{:ok, version}
	end

	defp db_upgrade(0, db) do
		:ok = :esqlite3.exec("create table vnc_event (" <>
			"  id integer not null primary key" <>
			"  ,time integer not null" <>
			"  ,type varchar(64) not null" <>
			"  ,json varchar(8192) not null" <>
			")", db)
		:ok = :esqlite3.exec("create index vnc_event_time on vnc_event (time)", db)
		:ok = :esqlite3.exec("create index vnc_event_type on vnc_event (type)", db)
		:ok = :esqlite3.exec("update version set version=1", db)
		db_upgrade(1, db)
	end

	defp db_upgrade(1, db) do
		# latest version, don't upgrade the database past this
		# verify the version is really 1
		[{1}] = :esqlite3.q("select version from version", db)
		{:ok, 1}
	end

	def event_insert(db, event) do
		{:ok, json} = Vnc.Event.encode(event)
		{:ok, dec} = Vnc.Event.decode(json)
		:"$done" = :esqlite3.exec("insert into vnc_event (time, type, json) values (?1, ?2, ?3)", [event.time, event.type, json], db)
		{:ok, dec}
	end
	
	def event_play(db, time) do
		{:ok, rs} = :esqlite3.prepare(
      "select * from vnc_event" <>
			" where time >= (" <>
			"   select max(time)" <>
			"   from vnc_event" <>
			"   where time <= ?1" <> 
			"   and type='keyframe')" <>
			" order by time", db)
		:ok = :esqlite3.bind(rs, [time])
		{:ok, rs}
	end

	def event_next(rs) do
		case :esqlite3.step(rs) do
			{:row, {_id, _time, _type, event}} -> 
				{:ok, event} = Vnc.Event.decode(event)
				{:vnc_event, event}
			:"$done" -> 
				:end
		end
	end
	
	def event_finalize(rs) do
		# TODO(nbk) shouldn't this be supported by esqlite3?
		# :esqlite3.finalize(rs)
		:ok
	end
end
