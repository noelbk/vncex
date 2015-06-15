defmodule Vnc.Event.Tile do
	defstruct [ :time, :x, :y, :w, :h, :file, :off, :len, type: :tile ]
end

defmodule Vnc.Event.Resize do
	defstruct [ :time, :w, :h, type: :resize ]
end

defmodule Vnc.Event.CopyRect do
	defstruct [ :time, :sx, :sy, :w, :h, :dx, :dy, type: :copyrect ]
end

defmodule Vnc.Event.Keyframe do
	defstruct [ :time, type: :keyframe ]
end

defmodule Vnc.Event.Password do
	defstruct [ :time, type: :password ]
end

defmodule Vnc.Event.Mouse do
	defstruct [ :time, :x, :y, :buttons, :event, type: :mouse ]
end

defmodule Vnc.Event.Keys do
	defstruct [ :time, :keys, type: :keys ]
end


defmodule Vnc.Event.CursorShape do
	defstruct [ :time, :x, :y, :w, :h, :file, :off, :len, type: :cursor_shape ]
end

defmodule Vnc.Event.CursorPos do
	defstruct [ :time, :x, :y, type: :cursor_pos ]
end

defmodule Vnc.Event.CursorLock do
	defstruct [ :time, :x, :y, :w, :h, type: :cursor_lock ]
end

defmodule Vnc.Event.CursorUnlock do
	defstruct [ :time, type: :cursor_unlock ]
end


defmodule Vnc.Event do
	def encode(event) do
		Poison.encode(event)
	end

	def decode(str) do
		{:ok, event} = Poison.decode(str, keys: :atoms!)
		{:ok, %{event | type: String.to_existing_atom(event.type)}}
	end
end


