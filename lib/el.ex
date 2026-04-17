defmodule El do
  def start(name) when is_atom(name) do
    {:ok, _pid} = ClaudeCode.start_link(name: name)
    name
  end

  def tell(name, message) do
    name
    |> ClaudeCode.stream(message)
    |> ClaudeCode.Stream.text_content()
    |> Enum.join()
  end
end
