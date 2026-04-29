defmodule El.CLI.Router do
  def parse_route([]), do: :usage
  def parse_route(["-v"]), do: :version
  def parse_route(["ls"]), do: :ls
  def parse_route(["exit"]), do: :exit_all
  def parse_route(["--daemon"]), do: :daemon_hub
  def parse_route(["--daemon", _name]), do: :daemon
  def parse_route(["--daemon", _name, "-m", _model]), do: :daemon
  def parse_route([_name, "log", _n]), do: :log_n
  def parse_route([_name, "log"]), do: :log
  def parse_route([_name, "exit"]), do: :exit
  def parse_route([_name, "clear"]), do: :clear

  def parse_route([_name, "tell", "ask", "@" <> _target | _words]) do
    :tell_ask
  end

  def parse_route([_name, "ask", "tell", "@" <> _target | _words]) do
    :ask_tell
  end

  def parse_route([<<c, _::binary>>]) when c != ?- do
    :start
  end

  def parse_route([<<c, _::binary>>, "-m", _model | _rest]) when c != ?- do
    :start
  end

  def parse_route([<<c, _::binary>>, "-a", _agent | _rest]) when c != ?- do
    :start
  end

  def parse_route([<<c, _::binary>>, _word | _more_words]) when c != ?- do
    :msg
  end

  def parse_route(_), do: :usage
end
