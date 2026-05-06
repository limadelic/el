defmodule El.Infra.GroupLeader do
  @behaviour El.Infra.Behaviours.GroupLeader

  def open_null_device do
    {:ok, dev} = File.open("/dev/null", [:write])
    dev
  end

  defdelegate close(dev), to: File
  def get, do: Process.group_leader()
  def set(pid, leader), do: Process.group_leader(pid, leader)
end
