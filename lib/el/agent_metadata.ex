defmodule El.AgentMetadata do
  def model_for(agent_name, search_dir \\ nil) do
    agent_name = normalize_name(agent_name)
    search_dir = search_dir || default_search_dir()
    file_path = Path.join(search_dir, "#{agent_name}.md")

    case File.read(file_path) do
      {:ok, content} -> extract_model_from_frontmatter(content)
      {:error, _} -> nil
    end
  end

  defp normalize_name(name) when is_atom(name), do: Atom.to_string(name)
  defp normalize_name(name) when is_binary(name), do: name

  defp default_search_dir do
    Path.expand("~/.claude/agents")
  end

  defp extract_model_from_frontmatter(content) do
    case String.split(content, "---", parts: 3) do
      [_, frontmatter, _] ->
        parse_frontmatter(frontmatter)

      _ ->
        nil
    end
  end

  defp parse_frontmatter(frontmatter) do
    lines = String.split(String.trim(frontmatter), "\n")

    Enum.find_value(lines, fn line ->
      trimmed = String.trim(line)

      case String.split(trimmed, ":", parts: 2) do
        ["model", value] -> String.trim(value)
        _ -> nil
      end
    end)
  end
end
