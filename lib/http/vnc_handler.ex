defmodule Http.VncHandler do
  @behaviour :cowboy_websocket_handler

  def init({_tcp, _http}, _req, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_TransportName, req, _opts) do
		# todo - find a vnc client for server:port and add a listener
		{:ok, vnc_client } = VNC.Client.start_link(self)
    {:ok, req, vnc_client }
  end

  # Required callback.  Put any essential clean-up here.
  def websocket_terminate(_reason, _req, _state) do
    :ok
  end

	# handle a message from the browser
  def websocket_handle({:text, content}, req, state) do
    { :ok, %{ "message" => message} } = JSEX.decode(content)
    { :reply, {:text, message}, req, state}
  end
	
	# TODO: messages from browser
	# :mouse
	# :key
	# :note
	# :seek
	# :pause/resume
	# :speed

  # handle messages from the vnc client
  def websocket_info({:vnc_client_msg, msg}, req, state) do
    { :ok, json } = JSEX.encode(Tuple.to_list(msg))
		# debug
		IO.puts "DEBUG: websocket_info{:vnc_client_msg} msg=#{inspect msg} json=#{json}"
    { :reply, {:text, json}, req, state}
  end

  # fallback message handler 
  def websocket_info(_info, req, state) do
    {:ok, req, state}
  end

end

