defmodule Vnc.Client do
	use GenServer
	use Timex

	defmodule Forwarder do
		use GenEvent

		def handle_event(event, parent) do
			send parent, event
			{:ok, parent}
		end
	end

	defmodule State do
		defstruct [events: nil, vnc_pid: nil, t0: nil, db: nil, db_path: nil, dir: nil]
	end

	def start_link(dir, opts \\ []) do
	
		{events, opts} = Keyword.pop(opts, :events)
		if events == nil do
			{:ok, events} = GenEvent.start_link
		end

		:ok = File.mkdir_p(dir)
		db_path = Path.join([dir, "vnc_client.db"])
		{:ok, db } = Vnc.Db.start_link(db_path)

		{listener, opts} = Keyword.pop(opts, :listener)
		if listener != nil do
			GenEvent.add_handler(events, Forwarder, listener)
		end

		{cmd, opts} = Keyword.pop(opts, :cmd, "./vnc_client")
		vnc_pid = :erlang.open_port({:spawn_executable, cmd}, [
																	{:args, [dir]},
																	:exit_status,
																	:stream,
																	{:line, 8192},
		])

		state = %State{events: events, 
									 vnc_pid: vnc_pid,
									 db: db,
									 db_path: db_path,
									 dir: dir,
									}
		GenServer.start_link(__MODULE__, state, opts)
	end

	@doc "stop and disconnect from vnc"
	def stop(server) do
    GenServer.call(server, :stop)
	end

	@doc "get a GenEvent pid to subscribe to messages"
	def events(server) do
    GenServer.call(server, :events)
	end

	@doc "return my db"
	def db(server) do
    GenServer.call(server, :db)
	end

	# GenServer callbacks

	def init(state) do
    :erlang.port_connect(state.vnc_pid, self())
		{:ok, state}
	end

	def handle_call(:stop, _from, state) do
		GenEvent.notify(state.events, {:vnc_client_stop, self()})
		{:stop, :normal, :ok, state}
	end

	@doc "return my event pid"
	def handle_call(:events, _from, state) do
		{:reply, {:ok, state.events}, state}
	end

	@doc "return my db"
	def handle_call(:db, _from, state) do
		{:reply, {:ok, state.db}, state}
	end
	
	@doc "process a complete line from my vnc subprocess"
	def handle_vnc_line(state, line) do
		int = fn s -> {i, ""} = Integer.parse(s); i; end
		event = case String.split(line) do
							["tile", x, y, w, h, file, off, len] -> 
								%Vnc.Event.Tile{x: int.(x), y: int.(y), w: int.(w), h: int.(h), 
																file: file, off: int.(off), len: int.(len)}
							["copyrect", sx, sy, w, h, dx, dy] -> 
								%Vnc.Event.CopyRect{sx: int.(sx), sy: int.(sy),
																		w: int.(w), h: int.(h),
																		dx: int.(dx), dy: int.(dy)}
							["resize", w, h] -> 
								%Vnc.Event.Resize{w: int.(w), h: int.(h)}
							["keyframe"] -> 
								%Vnc.Event.Keyframe{}
							["password?"] -> 
								%Vnc.Event.Password{}
							_ -> 
								{:error, line}
						end
		{:ok, event, state} = event_set_time(event, state)
		#Vnc.Db.event_insert(state.db, event)
		GenEvent.notify(state.events, {:vnc_event, self(), event})
		state
	end

	def handle_info({_port, {:data, {:eol, line}}}, state) do
	  state = handle_vnc_line(state, to_string(line))
		{:noreply, state}
	end

	def handle_info({_port, {:data, {:noeol, _line}}}, _state) do
		raise ArgumentError, message: "line buffer overflow"
	end

	## messages from client to server

	# type: :mouse, x: 4, y: 342, buttons: 0, event: "down"
	def handle_info(event=%{type: :mouse, x: x, y: y, buttons: buttons, event: mouse_event}, state) do
		{:ok, event, state} = event_set_time(event, state)
		Vnc.Db.event_insert(state.db, event)
		:erlang.port_command(state.vnc_pid, "mouse #{x} #{y} #{buttons} #{mouse_event}\n")
		{:noreply, state}
	end

	def event_set_time(event, state) do
		now = Time.now(:msecs)
		if state.t0 == nil do
			state = %{state | t0: now}
		end
		event = Map.put(event, :time, now - state.t0)
		{:ok, event, state}
	end
	
end
