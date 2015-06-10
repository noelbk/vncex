defmodule Http.Vnc.Handler do
	defmodule State do
		defstruct [ vnc_client: nil ]
	end

  def init(req, _opts) do
		{:ok, vnc_client} = VNC.Client.start_link(self)
    {:cowboy_websocket, req, %State{vnc_client: vnc_client}}
  end

	def terminate(reason, _req, state) do
		:erlang.exit(state.vnc_client, reason)
	end

	# handle a message from the browser
  def websocket_handle({:text, content}, req, state) do
		{:ok, msg} = Poison.decode(content)
		send(state.vnc_client, msg)
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
  def websocket_info({:vnc_client_msg, _pid, msg}, req, state) do
		case msg.type do
			:tile -> msg = %{msg | file: "/vnc_tile?file=#{msg.file}&off=#{msg.off}&len=#{msg.len}"}
			_ -> msg
		end
    {:ok, json} = Poison.encode(msg)
    {:reply, {:text, json}, req, state}
  end

  # fallback message handler 
  def websocket_info(msg, req, state) do
		# debug
		IO.puts "DEBUG: websocket_info unkown msg=#{inspect msg}"
    {:ok, req, state}
  end

end

