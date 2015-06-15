defmodule Http.Vnc.Handler do

	defmodule State do
		defstruct [ vnc_client: nil, vnc_player: nil ]
	end

  def init(req, _opts) do
		{:ok, vnc_client} = Vnc.Client.start_link("out", listener: self)
		#{:ok, vnc_player} = Vnc.Player.start_link(vnc_client, self)
    {:cowboy_websocket, req, %State{
													#vnc_player: vnc_player, 
													vnc_client: vnc_client,
		}}
  end

	def terminate(reason, _req, state) do
		:erlang.exit(state.vnc_client, reason)
	end

	# handle a message from the browser
  def websocket_handle({:text, json}, req, state) do
		{:ok, event} = Vnc.Event.decode(json)
		send(state.vnc_client, event)
    {:ok, req, state}
  end
	
	# TODO: messages from browser
	# :mouse
	# :key
	# :note
	# :seek
	# :pause/resume
	# :speed

  # handle messages from the vnc client
  def websocket_info({:vnc_event, _pid, event}, req, state) do
		reply_extra = []
		if event.type == :tile do
			if :true do
				# (faster) send the png in a binary hunk immediately
				{:ok, fd} = :file.open(event.file, [:read, :raw, :binary])
				{:ok, buf} = :file.pread(fd, event.off, event.len)
				:file.close(fd)
				reply_extra = [{:binary, buf}]
				event = %{event | file: nil}
			else
				# (slower) get the client to make a separate request to fetch the png
				event = %{event | file: "/vnc_tile?file=#{event.file}&off=#{event.off}&len=#{event.len}"}
			end
		end
    {:ok, json} = Vnc.Event.encode(event)
		reply = [{:text, json}] ++ reply_extra
    {:reply, reply, req, state}
  end

  # fallback message handler 
  def websocket_info(event, req, state) do
		# debug
		IO.puts "DEBUG: websocket_info unkown event=#{inspect event}"
    {:ok, req, state}
  end

end

