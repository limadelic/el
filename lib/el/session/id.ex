defmodule El.Session.Id do
  def format_uuid(hex) do
    <<a::binary-8, b::binary-4, c::binary-4, d::binary-4, e::binary-12>> = hex
    Enum.join([a, b, c, d, e], "-")
  end
end
