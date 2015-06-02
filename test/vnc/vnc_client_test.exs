defmodule VNC.ClientTest do 
	use ExUnit.Case, async: true

	defmodule PutsEvent do
		use GenEvent

		def handle_event(msg, state) do
			IO.puts "DEBUG: #{inspect msg}"
			{:ok, state}
		end
	end

	test "vnc_client events" do
		{:ok, vnc_client} = VNC.Client.start_link(self)
		{:ok, events} = VNC.Client.events(vnc_client)
		GenEvent.add_handler(events, PutsEvent, :ok)
		assert_receive({:vnc_client_line, ^vnc_client, _msg})
		assert_receive({:vnc_client_msg, ^vnc_client, {:tile, _x, _y, _w, _h, _file, _off, _len}})
		VNC.Client.stop(vnc_client)
		assert_receive({:vnc_client_stop, ^vnc_client})
	end
end
