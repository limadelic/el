defmodule El.DaemonWriter do
  def write_daemon_node_file do
    File.write!("/tmp/daemon_test_marker.txt", "write_daemon_node_file was called\n")

    home = System.get_env("HOME", "/tmp")
    node_file = Path.join(home, ".el/daemon_node")
    node_str = Atom.to_string(Node.self())

    File.mkdir_p!(Path.dirname(node_file))
    File.write!(node_file, node_str)
  end
end
