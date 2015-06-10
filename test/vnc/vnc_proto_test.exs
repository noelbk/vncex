defmodule VNC.Client.Protocol.Test do 
	use ExUnit.Case, async: true

	test "vnc_protocol" do
		{:ok, vnc_client} = VNC.Client.Protocol.start_link(self, [socket: :mock])a
		:protocol_version = VNC.Client.Protocol.state(vnc_client)
		send(vnc_client, {:tcp, nil, <<"RF">>})
		send(vnc_client, {:tcp, nil, <<"B 001.00">>})
		send(vnc_client, {:tcp, nil, <<"1\n">>})
		:security = VNC.Client.Protocol.state(vnc_client)
	end
end
