defmodule El.CLI.Start do
  def start_opts(nil), do: []
  def start_opts(model), do: [model: model]

  def normalize_model(""), do: nil
  def normalize_model(model), do: model

  def merge_session_opts(name, explicit_agent \\ nil, explicit_model \\ nil, deps \\ []) do
    agent = resolve_agent(explicit_agent, name, deps)
    base = build_base_opts(explicit_model, agent, deps)
    base ++ env_model(base)
  end

  defp build_base_opts(explicit_model, agent, deps) do
    start_opts(explicit_model) ++
      agent_opt(agent) ++
      agent_model_opt(agent, explicit_model, deps)
  end

  defp resolve_agent(nil, name, deps), do: agent_detector(deps).detect_agent(name)
  defp resolve_agent(agent, _name, _deps), do: agent

  def detect_and_merge_agent(name, opts, deps \\ []) do
    merged = opts ++ agent_opt(agent_detector(deps).detect_agent(name))
    merged ++ env_model(merged)
  end

  defp agent_detector(deps) do
    Keyword.get(deps, :agent_detector, El.AgentDetector)
  end

  defp agent_opt(nil), do: []
  defp agent_opt(agent), do: [agent: agent]

  defp agent_model_opt(nil, _, _), do: []
  defp agent_model_opt(_, explicit_model, _) when explicit_model != nil, do: []
  defp agent_model_opt(agent, nil, deps) do
    metadata = agent_metadata(deps)
    agent_model_for(metadata.model_for(agent))
  end

  defp agent_metadata(deps) do
    Keyword.get(deps, :agent_metadata, El.AgentMetadata)
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

  def handle_find_daemon_for_start(name, opts, el, deps \\ []) do
    name_atom = String.to_atom(name)
    el.start(name_atom, opts ++ deps)
    ping_if_agent(name_atom, opts, deps)
    print_session_info(name, opts, deps)
  end

  defp ping_if_agent(name_atom, opts, deps) do
    do_ping(name_atom, Keyword.get(opts, :agent), session_api(deps).info(name_atom), deps)
  end

  defp do_ping(_name_atom, nil, _info, _deps), do: :ok
  defp do_ping(_name_atom, _agent, %{messages: messages}, _deps) when messages > 0, do: :ok
  defp do_ping(name_atom, _agent, _info, deps), do: quiet_ask(name_atom, deps)

  # try/after for IO cleanup — CC violation is intentional
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp quiet_ask(name_atom, deps) do
    {original, null_device, gl} = redirect_to_null(deps)
    ask_fn = fn -> session_api(deps).ask(name_atom, "who are you?") end
    try(do: ask_fn.(), after: restore_io(gl, original, null_device))
  end

  defp redirect_to_null(deps) do
    gl = group_leader(deps)
    null_device = gl.open_null_device()
    original = gl.get()
    gl.set(self(), null_device)
    {original, null_device, gl}
  end

  defp restore_io(gl, original, null_device) do
    gl.set(self(), original)
    gl.close(null_device)
  end

  def print_session_info(name, opts, deps \\ []) do
    info = session_api(deps).info(String.to_atom(name))
    rows = build_card_rows(name, opts, info)
    box_frame(rows) |> Enum.each(&IO.puts/1)
  end

  defp build_card_rows(name, opts, info) do
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
    rows ++ [frame_pair_row(left, right)]
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
    rows ++ [frame_pair_row(left, right)]
  end

  defp add_model(rows, nil, nil), do: rows
  defp add_model(rows, nil, info_model), do: rows ++ ["model: #{info_model}"]
  defp add_model(rows, opts_model, _info_model), do: rows ++ ["model: #{opts_model}"]

  defp add_msgs(rows, 0), do: rows
  defp add_msgs(rows, count), do: rows ++ ["msgs:  #{count}"]

  defp add_prompt_separator(rows, nil), do: rows
  defp add_prompt_separator(rows, _prompt), do: rows ++ [String.duplicate("─", 46)]

  defp add_prompt(rows, nil), do: rows
  defp add_prompt(rows, prompt), do: rows ++ ["> #{prompt}"]

  defp add_response_separator(rows, nil), do: rows
  defp add_response_separator(rows, _response), do: rows ++ [String.duplicate("─", 46)]

  defp add_response_lines(rows, nil), do: rows
  defp add_response_lines(rows, response), do: rows ++ El.CLI.Start.TextFormatter.format_response(response)

  defp session_api(deps) do
    Keyword.get(deps, :session_api, El.Session.Api)
  end

  defp group_leader(deps) do
    Keyword.get(deps, :group_leader, El.GroupLeaderImpl)
  end

  defp box_frame([]), do: [top_border(), bottom_border()]
  defp box_frame(rows) do
    first_two = Enum.take(rows, 2)
    rest = Enum.drop(rows, 2)
    [top_border()] ++ first_two ++ Enum.map(rest, &frame_row/1) ++ [bottom_border()]
  end

  defp top_border, do: "╭" <> String.duplicate("─", 48) <> "╮"
  defp bottom_border, do: "╰" <> String.duplicate("─", 48) <> "╯"

  defp frame_row(content) do
    padded = String.pad_trailing(content, 46)
    "│ " <> padded <> " │"
  end

  defp frame_pair_row(left, right) do
    right_block = truncate_right_block(right)
    content = compose_pair_content(left, right_block)
    "│ " <> String.pad_trailing(content, 46) <> " │"
  end

  defp compose_pair_content(left, right_block) do
    left <> filler_between(left, right_block) <> right_block
  end

  defp filler_between(left, right) do
    String.duplicate(" ", filler_length(left, right))
  end

  defp filler_length(left, right) do
    max(0, 46 - String.length(left) - String.length(right))
  end

  defp truncate_right_block(right) do
    do_truncate_right(String.split(right, ": ", parts: 2), right)
  end

  defp do_truncate_right([label, value], _right), do: label <> ": " <> truncate_value(value)
  defp do_truncate_right(_parts, right), do: right

  defp truncate_value(value) do
    truncate_with_ellipsis(value, 9)
  end

  defp truncate_with_ellipsis(text, max_len) do
    text_len = String.length(text)
    do_truncate(text_len, text, max_len)
  end

  defp do_truncate(len, text, max_len) when len <= max_len, do: text
  defp do_truncate(_len, text, max_len) do
    ellipsis = "…"
    available = max_len - String.length(ellipsis)
    ellipsis <> String.slice(text, -available..-1)
  end

  def handle_find_daemon_with_rest(name, opts, rest, el, deps \\ []) do
    name_atom = String.to_atom(name)
    el.start(name_atom, opts ++ deps)
    print_session_info(name, opts, deps)
    dispatch_rest(rest, name, opts)
  end

  def dispatch_rest([], _name, _opts) do
    :ok
  end

  def dispatch_rest(rest, name, opts) do
    El.CLI.dispatch([name | rest], opts)
  end

  def start_daemon_node_for(name, model, el, sleeper \\ El.SleeperImpl, deps \\ []) do
    name_atom = String.to_atom(name)
    el.start(name_atom, start_opts(normalize_model(model)) ++ deps)
    report_daemon_up(name)
    hold_forever(sleeper)
  end

  defp report_daemon_up(name) do
    IO.puts("el: #{name} is up on #{Node.self()}")
  end

  defp hold_forever(sleeper) do
    sleeper.sleep(:infinity)
  end
end
