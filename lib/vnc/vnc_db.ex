defmodule VNC.Client.Db do
	use GenServer

	defmodule State do
		defstruct [ :db, :listener ]
	end

	def start_link(vnc_client, filename, opts \\ []) do
		{:ok, listener} = vnc_client.listen_events(self())
		{:ok, db} = db_open(filename)
		state = %State{db: db, listener: listener}
		GenServer.start_link(__MODULE__, state, opts)
	end

	def db_open(filename) do
		{:ok, db} = :esqlite3.open(filename)
		{:ok, _version} = db_upgrade(db)
		{:ok, db}
	end

	def db_upgrade(db) do
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

	def db_upgrade(0, db) do
		:ok = :esqlite3.exec("create table vnc_event (" <>
			"  id integer not null primary key" <>
			"  ,time decimal(18,6) not null" <>
			"  ,event varchar(128) not null" <>
			"  ,params varchar(8192) not null" <>
			")", db)
		:ok = :esqlite3.exec("create index vnc_event_time on vnc_event (time)", db)
		:ok = :esqlite3.exec("create index vnc_event_event on vnc_event (event)", db)
		:ok = :esqlite3.exec("update version set version=1", db)
		db_upgrade(1, db)
	end

	def db_upgrade(1, db) do
		# latest version, don't upgrade the database past this
		# verify the version is really 1
		[{1}] = :esqlite3.q("select version from version", db)
		{:ok, 1}
	end

	def insert_event(db, time, event, params) do
		{:ok, st } = :esqlite3.prepare("insert into vnc_event (time, event, params) values (?1, ?2, ?3)", db)
		:esqlite3.bind(st, [time, event, params])
		:esqlite3.step(st)
	end
	
	def seek(db, time) do
		:esqlite3.exec("select * from vnc_event" <>
			" where time >= (" <>
			"   select max(time)" <>
			"   from vnc_event ve2" <>
			"   where time <= ?1" <> 
			"   and ve2.event='keyframe')" <>
			" and time <= ?1" <>
			" order by time", [time], db)
	end
	
	def play(db, time) do
	end
end
