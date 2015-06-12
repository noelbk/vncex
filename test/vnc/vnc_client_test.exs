defmodule Vnc.Client.Test do 
	use ExUnit.Case, async: true

	defmodule PutsEvent do
		use GenEvent

		def handle_event(msg, state) do
			IO.puts "DEBUG: #{inspect msg}"
			{:ok, state}
		end
	end

	defmodule FuncEvent do
		use GenEvent

		def handle_event(msg, func) do
			func.(msg)
			{:ok, func}
		end
	end

	test "vnc_client events" do
		{:ok, vnc_client} = Vnc.Client.start_link("test/vnc_client_test", [cmd: "test/vnc_client_mock", listener: self])
		#{:ok, _vnc_player} = Vnc.Player.start_link(vnc_client, self)
		{:ok, events} = Vnc.Client.events(vnc_client)

		myself = self()
		myfunc = fn(msg) ->
			send myself,  {:myfunc, elem(msg, 0)}
		end
		GenEvent.add_handler(events, FuncEvent, myfunc)

		assert_receive({:vnc_event, ^vnc_client, %Vnc.Event.Tile{}})
		assert_receive({:myfunc, :vnc_event})
		Vnc.Client.stop(vnc_client)
		assert_receive({:vnc_client_stop, ^vnc_client})
		assert_receive({:myfunc, :vnc_client_stop})
	end
end
