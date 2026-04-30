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
    content
    |> String.split("---", parts: 3)
    |> extract_frontmatter_parts()
  end

  defp extract_frontmatter_parts([_, frontmatter, _]), do: parse_frontmatter(frontmatter)
  defp extract_frontmatter_parts(_), do: nil

  defp parse_frontmatter(frontmatter) do
    lines = String.split(String.trim(frontmatter), "\n")
    Enum.find_value(lines, &extract_model_line/1)
  end

  defp extract_model_line(line) do
    trimmed = String.trim(line)
    extract_model_value(String.split(trimmed, ":", parts: 2))
  end

  defp extract_model_value(["model", value]), do: String.trim(value)
  defp extract_model_value(_), do: nil
end
