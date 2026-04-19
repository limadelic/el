Before do
  # Clean up stale daemon node file before each scenario
  daemon_node_file = File.expand_path("~/.el/daemon_node")
  File.delete(daemon_node_file) if File.exist?(daemon_node_file)
end

After do
  if @pid
    Process.kill("TERM", @pid) rescue nil
  end

  # Clean up daemon node file after scenario
  daemon_node_file = File.expand_path("~/.el/daemon_node")
  File.delete(daemon_node_file) if File.exist?(daemon_node_file)
end
