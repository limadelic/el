defmodule El.CLI.Start do
  def start_opts(nil), do: []
  def start_opts(model), do: [model: model]

  def normalize_model(""), do: nil
  def normalize_model(model), do: model

  def merge_session_opts(name, explicit_agent \\ nil, explicit_model \\ nil) do
    model_opts = start_opts(explicit_model)
    agent = explicit_agent || agent_detector().detect_agent(name)
    agent_opts = agent_opt(agent)
    agent_model_opts = agent_model_opt(agent, explicit_model)
    result = model_opts ++ agent_opts ++ agent_model_opts
    result ++ env_model(result)
  end

  def detect_and_merge_agent(name, opts) do
    merged = opts ++ agent_opt(agent_detector().detect_agent(name))
    merged ++ env_model(merged)
  end

  defp agent_detector do
    Application.get_env(:el, :agent_detector, El.AgentDetector)
  end

  defp agent_opt(nil), do: []
  defp agent_opt(agent), do: [agent: agent]

  defp agent_model_opt(nil, _), do: []
  defp agent_model_opt(_, explicit_model) when explicit_model != nil, do: []
  defp agent_model_opt(agent, nil) do
    agent_metadata = Application.get_env(:el, :agent_metadata, El.AgentMetadata)
    agent_model_for(agent_metadata.model_for(agent))
  end

  defp agent_model_for(nil), do: []
  defp agent_model_for(model), do: [model: model]

  defp env_model(opts) do
    env_model_for(Keyword.get(opts, :model), Keyword.get(opts, :agent))
  end

  defp env_model_for(nil, nil) do
    subagent_model(System.get_env("CLAUDE_CODE_SUBAGENT_MODEL"))
  end

  defp env_model_for(_, _), do: []

  defp subagent_model(nil), do: []
  defp subagent_model(model), do: [model: model]

  def handle_find_daemon_for_start(name, opts, el) do
    name_atom = String.to_atom(name)
    el.start(name_atom, opts)
    ping_if_agent(name_atom, opts)
    print_session_info(name, opts)
  end

  defp ping_if_agent(name_atom, opts), do: do_ping(name_atom, Keyword.get(opts, :agent))

  defp do_ping(_name_atom, nil), do: :ok
  defp do_ping(name_atom, _agent), do: quiet_ask(name_atom)

  defp quiet_ask(name_atom) do
    {:ok, null_device} = File.open("/dev/null", [:write])
    original = Process.group_leader()
    Process.group_leader(self(), null_device)
    result = session_api().ask(name_atom, "who are you?")
    Process.group_leader(self(), original)
    File.close(null_device)
    result
  end

  defp print_session_info(name, opts) do
    info = session_api().info(String.to_atom(name))
    rows = build_card_rows(name, opts, info)
    box_frame(rows) |> Enum.each(&IO.puts/1)
  end

  defp build_card_rows(name, opts, info) do
    []
    |> add_name(name)
    |> add_agent(Keyword.get(opts, :agent))
    |> add_model(Keyword.get(opts, :model))
    |> add_msgs(info.messages)
    |> add_prompt_separator(info.last_prompt)
    |> add_prompt(info.last_prompt)
    |> add_response_separator(info.last_response)
    |> add_response_lines(info.last_response)
  end

  defp add_name(rows, name), do: rows ++ ["name:  #{name}"]

  defp add_agent(rows, nil), do: rows
  defp add_agent(rows, agent), do: rows ++ ["agent: #{agent}"]

  defp add_model(rows, nil), do: rows
  defp add_model(rows, model), do: rows ++ ["model: #{model}"]

  defp add_msgs(rows, messages), do: rows ++ ["msgs:  #{messages}"]

  defp add_prompt_separator(rows, nil), do: rows
  defp add_prompt_separator(rows, _prompt), do: rows ++ [String.duplicate("─", 46)]

  defp add_prompt(rows, nil), do: rows
  defp add_prompt(rows, prompt), do: rows ++ ["> #{prompt}"]

  defp add_response_separator(rows, nil), do: rows
  defp add_response_separator(rows, _response), do: rows ++ [String.duplicate("─", 46)]

  defp add_response_lines(rows, nil), do: rows
  defp add_response_lines(rows, response), do: rows ++ format_response(response)

  defp session_api do
    Application.get_env(:el, :session_api, El.Session.Api)
  end

  defp box_frame([]), do: [top_border(), bottom_border()]
  defp box_frame(rows) do
    [top_border()] ++ Enum.map(rows, &frame_row/1) ++ [bottom_border()]
  end

  defp top_border, do: "╭" <> String.duplicate("─", 48) <> "╮"
  defp bottom_border, do: "╰" <> String.duplicate("─", 48) <> "╯"

  defp frame_row(content) do
    padded = String.pad_trailing(content, 46)
    "│ " <> padded <> " │"
  end

  def format_response(nil), do: []
  def format_response(response) do
    response
    |> wrap_text(46)
    |> cap_lines(2)
  end

  defp wrap_text(text, width) do
    text
    |> String.split(" ")
    |> build_lines(width, "", [])
  end

  defp build_lines([], _width, "", acc), do: Enum.reverse(acc)
  defp build_lines([], _width, current, acc), do: Enum.reverse([String.trim(current) | acc])

  defp build_lines([word | rest], width, "", acc) do
    build_lines(rest, width, word, acc)
  end

  defp build_lines([word | rest], width, current, acc) do
    add_word(word, rest, width, current, acc, String.trim(current <> " " <> word))
  end

  defp add_word(word, rest, width, current, acc, new_line) do
    do_add_word(String.length(new_line), word, rest, width, current, acc, new_line)
  end

  defp do_add_word(len, _word, rest, width, _current, acc, new_line) when len <= width do
    build_lines(rest, width, new_line, acc)
  end

  defp do_add_word(_len, word, rest, width, current, acc, _new_line) do
    build_lines(rest, width, word, [String.trim(current) | acc])
  end

  defp cap_lines(lines, max), do: Enum.take(lines, max)

  def handle_find_daemon_with_rest(name, opts, rest, el) do
    name_atom = String.to_atom(name)
    el.start(name_atom, opts)
    print_session_info(name, opts)
    dispatch_rest(rest, name)
  end

  def dispatch_rest([], _name) do
    :ok
  end

  def dispatch_rest(rest, name) do
    El.CLI.dispatch([name | rest])
  end

  def start_daemon_node_for(name, model, el) do
    name_atom = String.to_atom(name)
    el.start(name_atom, start_opts(normalize_model(model)))
    report_daemon_up(name)
    hold_forever()
  end

  defp report_daemon_up(name) do
    IO.puts("el: #{name} is up on #{Node.self()}")
  end

  defp hold_forever do
    Process.sleep(:infinity)
  end
end
