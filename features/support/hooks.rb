After do
  if @pid
    Process.kill("TERM", @pid) rescue nil
  end
end
