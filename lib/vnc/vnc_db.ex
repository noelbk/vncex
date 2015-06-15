defmodule Vnc.Db do
	use GenServer

	@insert_commit_timeout 10

	defmodule State do
		defstruct [db: nil, sql_prep: %{}, in_transaction: false]
	end

	def start_link(filename, opts \\ []) do
		{:ok, db, _version} = open(filename)
		state = %State{ db: db }
		GenServer.start_link(__MODULE__, state, opts)
	end

	def event_insert(server, event) do
		{:ok, json} = Vnc.Event.encode(event)
		{:ok, decoded} = Vnc.Event.decode(json)
    GenServer.cast(server, {:event_insert, event})
		# return a decoded version of the event so the unit tests have something to compare it to
		{:ok, decoded}
	end
	
	def event_play(server, time) do
    GenServer.call(server, {:event_play, time})
	end

	def event_next(server, rs) do
    GenServer.call(server, {:event_next, rs})
	end
	
	def event_finalize(server, rs) do
    GenServer.call(server, {:event_finalize, rs})
	end


	def init(state) do
		{:ok, state}
	end
	
	defp open(filename) do
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

		# tips from http://stackoverflow.com/questions/1711631/improve-insert-per-second-performance-of-sqlite
		# too risky though.  I want to make sure the database is not corrupt after termination
		#:ok = :esqlite3.exec("pragma synchronous = off", db)
		#:ok = :esqlite3.exec("pragma journal_mode = memory", db)

		{:ok, 1}
	end

	def sql_prep_exec(sql, values, state) do
		{st, state} = case Map.get(state.sql_prep, sql) do 
										nil ->
											{:ok, st} = :esqlite3.prepare(sql, state.db)
											{st, %{state | sql_prep: Map.put(state.sql_prep, sql, st)}}
										st ->
											{st, state}
									end
		:ok = :esqlite3.bind(st, values)
		{:ok, state, :esqlite3.step(st)}
	end

	def commit(state) do
		if state.in_transaction do
			:esqlite3.exec("commit", state.db)
			{:ok, %{state | in_transaction: false}}
		else
			{:ok, state}
		end
	end
	
	def begin(state) do
		if state.in_transaction do
			{:ok, state}
		else
			:timer.send_after(@insert_commit_timeout, :commit)
			:esqlite3.exec("begin", state.db)
			{:ok, %{state | in_transaction: true}}
		end
	end


	def handle_cast({:event_insert, event}, state) do
		{:ok, json} = Vnc.Event.encode(event)

		# try to insert several events in a single transaction
		if event.type == :keyframe do
			{:ok, state} = commit(state)
		end
		{:ok, state} = begin(state)

		{:ok, state, :"$done"} = sql_prep_exec("insert into vnc_event (time, type, json) values (?1, ?2, ?3)", 
																					 [event.time, event.type, json], state)
		{:noreply, state}
	end
	
	def handle_call({:event_play, time}, _from, state) do
		{:ok, state} = commit(state)
		{:ok, rs} = :esqlite3.prepare(
      "select * from vnc_event" <>
			" where time >= (" <>
			"   select max(time)" <>
			"   from vnc_event" <>
			"   where time <= ?1" <> 
			"   and type='keyframe')" <>
			" order by time", state.db)
		:ok = :esqlite3.bind(rs, [time])
		{:reply, {:ok, rs}, state}
	end

	def handle_call({:event_next, rs}, _from, state) do
		case :esqlite3.step(rs) do
			{:row, {_id, _time, _type, event}} -> 
				{:ok, event} = Vnc.Event.decode(event)
				{:reply, {:vnc_event, event}, state}
			:"$done" -> 
				{:reply, :end, state}
		end
	end
	
	def handle_call({:event_finalize, _rs}, _from, state) do
		# TODO(nbk) shouldn't this be supported by esqlite3?
		# :esqlite3.finalize(rs)
		{:reply, :ok, state}
	end

	def handle_info(:commit, state) do
		{:ok, state} = commit(state)
		{:noreply, state}
	end
end
	
