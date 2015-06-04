# see https://github.com/ninenines/cowboy/blob/master/examples/websocket/src/ws_handler.erl
defmodule WebsocketHandler do
  # We are using the websocket handler.  See the documentation here:
  #     http://ninenines.eu/docs/en/cowboy/HEAD/manual/websocket_handler/
  #
  # All cowboy HTTP handlers require an init() function, identifies which
  # type of handler this is and returns an initial state (if the handler
  # maintains state).  In a websocket handler, you return a 
  # 3-tuple with :upgrade as shown below.  This is essentially following
  # the specification of websocket, in which a plain HTTP request is made
  # first, which requests an upgrade to the websocket protocol.
  def init(req, opts) do
    :erlang.start_timer(1000, self(), [])
    {:cowboy_websocket, req, opts}
  end

  # websocket_handle deals with messages coming in over the websocket.
  # it should return a 4-tuple starting with either :ok (to do nothing)
  # or :reply (to send a message back).  
  def websocket_handle({:text, content}, req, state) do

    # Use JSEX to decode the JSON message and extract the word entered
    # by the user into the variable 'message'.
    { :ok, %{ "message" => message} } = Poison.decode(content)

    # Reverse the message and use JSEX to re-encode a reply contatining
    # the reversed message.
    rev = String.reverse(message)
    { :ok, reply } = Poison.encode(%{ reply: rev})

    #IO.puts("Message: #{message}")
    
    # The reply format here is a 4-tuple starting with :reply followed 
    # by the body of the reply, in this case the tuple {:text, reply} 
    {:reply, {:text, reply}, req, state}
  end
  
  # Fallback clause for websocket_handle.  If the previous one does not match
  # this one just returns :ok without taking any action.  A proper app should
  # probably intelligently handle unexpected messages.
  def websocket_handle(_data, req, state) do    
    {:ok, req, state}
  end

  # websocket_info is the required callback that gets called when erlang/elixir
  # messages are sent to the handler process.  In this example, the only erlang 
  # messages we are passing are the :timeout messages from the timing loop. 
  #
  # In a larger app various clauses of websocket_info might handle all kinds
  # of messages and pass information out the websocket to the client.
  def websocket_info({_timeout, _ref, _foo}, req, state) do

    time = time_as_string()

    # encode a json reply in the variable 'message'
    { :ok, message } = JSEX.encode(%{ time: time})

    
    # set a new timer to send a :timeout message back to this process a second
    # from now.
    :erlang.start_timer(1000, self(), [])

    # send the new message to the client. Note that even though there was no
    # incoming message from the client, we still call the outbound message 
    # a 'reply'.  That makes the format for outbound websocket messages 
    # exactly the same as websocket_handle()
    { :reply, {:text, message}, req, state}
  end

  # fallback message handler 
  def websocket_info(_info, req, state) do
    {:ok, req, state}
  end

  def time_as_string do
    {hh,mm,ss} = :erlang.time()
    :io_lib.format("~2.10.0B:~2.10.0B:~2.10.0B",[hh,mm,ss])
      |> :erlang.list_to_binary()
  end

end

