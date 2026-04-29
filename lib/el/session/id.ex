defmodule El.Session.Id do
  def generate_session_id do
    <<a::48, _::4, b::12, _::2, c::62>> = :crypto.strong_rand_bytes(16)
    uuid_bytes = <<a::48, 4::4, b::12, 2::2, c::62>>
    Base.encode16(uuid_bytes, case: :lower) |> format_uuid()
  end

  def format_uuid(hex) do
    <<a::binary-8, b::binary-4, c::binary-4, d::binary-4, e::binary-12>> = hex
    Enum.join([a, b, c, d, e], "-")
  end

  def session_id(nil), do: generate_session_id()
  def session_id(id), do: id

  def extract_resume_or_id(opts) do
    {resume, rest} = Keyword.pop(opts, :resume)
    {session_id(resume), rest}
  end
end
