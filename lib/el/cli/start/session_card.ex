defmodule El.CLI.Start.SessionCard do
  def build_card_rows(name, opts, info) do
    []
    |> add_identity(name, opts, info)
    |> add_stats(opts, info)
    |> add_message_history(info)
  end

  defp add_identity(rows, name, opts, info) do
    rows
    |> add_name_id(name, info.id)
    |> add_second_with_cwd(opts[:agent], opts[:model], info.model, info.cwd)
  end

  defp add_stats(rows, opts, info) do
    rows
    |> add_model(opts[:model], info.model)
    |> add_msgs(info.messages)
  end

  defp add_message_history(rows, info) do
    rows
    |> add_prompt_section(info.last_prompt)
    |> add_response_section(info.last_response)
  end

  defp add_prompt_section(rows, prompt) do
    rows
    |> add_prompt_separator(prompt)
    |> add_prompt(prompt)
  end

  defp add_response_section(rows, response) do
    rows
    |> add_response_separator(response)
    |> add_response_lines(response)
  end

  defp add_name_id(rows, name, id) do
    left = "name:  #{name}"
    right = "id: #{id}"
    rows ++ [card_box().frame_pair_row(left, right)]
  end

  defp add_second_with_cwd(rows, agent, opts_model, info_model, cwd) do
    second_left = second_left_value(agent, opts_model, info_model)
    do_add_second_with_cwd(rows, second_left, cwd)
  end

  defp second_left_value(agent, _, _) when agent != nil, do: "agent: #{agent}"
  defp second_left_value(nil, opts_model, _) when opts_model != nil, do: "model: #{opts_model}"
  defp second_left_value(nil, nil, info_model) when info_model != nil, do: "model: #{info_model}"
  defp second_left_value(_, _, _), do: nil

  defp do_add_second_with_cwd(rows, nil, _cwd), do: rows
  defp do_add_second_with_cwd(rows, left, cwd) do
    right = "cwd: #{cwd}"
    rows ++ [card_box().frame_pair_row(left, right)]
  end

  defp add_model(rows, nil, nil), do: rows
  defp add_model(rows, nil, info_model), do: rows ++ ["model: #{info_model}"]
  defp add_model(rows, opts_model, _info_model), do: rows ++ ["model: #{opts_model}"]

  defp add_msgs(rows, 0), do: rows
  defp add_msgs(rows, count), do: rows ++ ["msgs:  #{count}"]

  defp add_prompt_separator(rows, nil), do: rows
  defp add_prompt_separator(rows, _prompt), do: rows ++ [String.duplicate("─", 46)]

  defp add_prompt(rows, nil), do: rows
  defp add_prompt(rows, prompt), do: rows ++ text_formatter().format_prompt(prompt)

  defp add_response_separator(rows, nil), do: rows
  defp add_response_separator(rows, _response), do: rows ++ [String.duplicate("─", 46)]

  defp add_response_lines(rows, nil), do: rows
  defp add_response_lines(rows, response), do: rows ++ text_formatter().format_response(response)

  defp card_box, do: Application.get_env(:el, :card_box, El.CLI.Start.CardBox)
  defp text_formatter, do: Application.get_env(:el, :text_formatter, El.CLI.Start.TextFormatter)
end
