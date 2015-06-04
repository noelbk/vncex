defmodule Vnc.Event.Tile do
	defstruct [ :x, :y, :w, :h, :file, :off, :len, type: :tile ]
end

defmodule VNC.Client do
	use GenServer

	defmodule Forwarder do
		use GenEvent

		def handle_event(event, parent) do
			send parent, event
			{:ok, parent}
		end
	end

	defmodule State do
		defstruct [events: nil, vnc_pid: nil]
	end

	def start_link(sendto \\ nil, opts \\ []) do

		{events, opts} = Keyword.pop(opts, :events)
		if events == nil do
			{:ok, events} = GenEvent.start_link
		end

		if sendto != nil do
			GenEvent.add_handler(events, Forwarder, sendto)
		end

		state = %State{events: events}
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

	# GenServer callbacks

	def init(state) do
		vnc_pid = :erlang.open_port({:spawn_executable, "./vnc_client"}, [
																		:exit_status,
																		:stream,
																		{:line, 8192}
		])
		state = %{state | vnc_pid: vnc_pid}
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

	@doc "process a complete line from my vnc subprocess"
	def handle_vnc_line(state, line) do
		int = fn s -> {i, ""} = Integer.parse(s); i; end
		msg = case String.split(line) do
						["tile", x, y, w, h, file, off, len] -> 
							%Vnc.Event.Tile{x: int.(x), y: int.(y), w: int.(w), h: int.(h), 
															file: file, off: int.(off), len: int.(len)}
						_ -> 
							{:error, line}
					end
		GenEvent.notify(state.events, {:vnc_client_msg, self(), msg})
		state
	end

	def handle_info({_port, {:data, {:eol, line}}}, state) do
	  state = handle_vnc_line(state, to_string(line))
		{:noreply, state}
	end

	def handle_info({_port, {:data, {:noeol, _line}}}, _state) do
		raise ArgumentError, message: "line buffer overflow"
	end

end