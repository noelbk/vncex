defmodule Vnc.Player do
	use GenServer
	use Timex
	
	defmodule State do
		defstruct [
			:vnc_client,
			:listener,
			:play_start,      # time in recording that playback started
			:play_last,       # time in recording of last played event
			:play_t0,         # real time when playback started
			play_speed: 1,    # time multiplier for ffwd or rew
			playing: :true,   # play or pause
			play_rs: nil,     # a record set from the database to play
		]
	end

	def start_link(vnc_client, listener, opts \\ []) do
		state = %State{vnc_client: vnc_client, listener: listener}
    GenServer.start_link(__MODULE__, state, opts)
	end

	## public API
	
	@doc "toggle the playing state. returns {:ok, playing}"
	def play(server) do
    GenServer.call(server, :play)
	end

	@doc "seek to a new time, in millis.  Returns :ok"
	def seek(server, time) do
    GenServer.call(server, {:seek, time})
	end

	## private functions

	@doc "emit a vnc play event to my listeners"
	def send_event(event, state) do
		send(state.listener, event)
		{:ok, %{state | play_last: event.time}}
	end

	@doc "return the current time that should be displayed in playback.  If playing"
	def play_time(state) do
		if state.playing do
			state.play_start + (Time.time(:millis) - state.play_t0) * state.play_speed
		else
			state.play_time
		end
	end

	## GenServer callbacks

	def init(state) do
		:erlang.monitor(:process, state.vnc_client)
		{:ok, state}
	end

	def handle_call(:play, _from, state) do
		playing = not state.playing
		state = %{state |
							playing: playing, 
							play_t0: Time.time(:millis), 
							play_start: state.play_last,
						 }
		{:reply, {:ok, playing}, state}
	end

	def handle_call({:seek, time}, _from, state) do
		{:ok, play_rs} = Vnc.Db.seek(time)
		{:ok, _play_tref} = :timer.send_after(0, {:play_rs})
		state = %{state | 
							play_rs: play_rs, 
							play_time: time,
							play_event: nil,
						 }
		{:noreply, state}
	end

	def handle_info(msg={:vnc_event, _vnc_client, _msg}, state) do
		# if I'm playing, and I'm not replaying a rs, then continue in realtime
		if state.playing and not state.play_rs do
			{:ok, state} = send_event(msg, state)
		end
		{:noreply, state}
	end

	def handle_info(:play_rs, sender, state) do
		# try to get an event from a recordset and play it.  
		case Vnc.Db.step(state.play_rs) do
			{:event, event} ->
				{:ok, play_time} = play_time(state)
				if event.time > play_time do
					# If the event time is in the future, then set a timer.
					{:ok, _play_tref} = :timer.send_after((event.time - play_time)/self.play_speed, {:play_rs, event})
					{:noreply, state}
				else
					{:ok, state} = send_event(event, state)
					handle_info(:play_rs, sender, state)
				end
			:end ->
				# clear the recordset at the end
				state = %{state | 
									play_rs: nil,
									play_t0: Time.time(:millis),
								 }
				{:noreply, state}
		end
	end

	def handle_info({:play_rs, event}, sender, state) do
		{:ok, state} = send_event(event, state)
		handle_info(:play_rs, sender, state)
	end
	

end
