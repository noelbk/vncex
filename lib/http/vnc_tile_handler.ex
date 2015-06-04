# serve VNC tiles using sendfile
defmodule Http.Vnc.TileHandler do
	def init(req, opts) do
		args = :cowboy_req.match_qs([file: :nonempty, off: :int, len: :int], req)
		sf = fn(socket, transport) ->
			transport.sendfile(socket, args.file, args.off, args.len)
		end
		req = :cowboy_req.set_resp_body_fun(args.len, sf, req)
		reply = :cowboy_req.reply(200, [ {"content-type", "image/png"} ], req)
    { :ok, reply, opts }
	end
end
