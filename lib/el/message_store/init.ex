defmodule El.MessageStore.Init do
  @behaviour El.Behaviours.MessageStoreInit

  def dets_path(dir, file) do
    Path.expand("#{dir}/#{file}.dets") |> String.to_charlist()
  end

  def store_dir(true), do: "~/.el/dev"
  def store_dir(false), do: "~/.el"
  def store_dir(daemon) when is_atom(daemon), do: store_dir(daemon.dev?())

  def setup_dir(opts) do
    dir = store_dir(Keyword.fetch!(opts, :daemon))
    expanded = Path.expand(dir)
    Keyword.fetch!(opts, :file_system).mkdir_p!(expanded)
    dir
  end

  def open_dets(backend, name, path) do
    {:ok, _} = backend.open_file(name, file: path, type: :bag)
  end

  def open_dets_files(dir, dets_backend) do
    open_dets(dets_backend, :message_store, dets_path(dir, "messages"))
    open_dets(dets_backend, :session_meta, dets_path(dir, "session_meta"))
  end

  def init_message_store(opts \\ []) do
    dir = setup_dir(opts)
    open_dets_files(dir, Keyword.fetch!(opts, :dets_backend))
  end

  def message_store_opts do
    [
      file_system: Application.get_env(:el, :file_system, El.FileSystemImpl),
      dets_backend: Application.get_env(:el, :dets_backend, :dets),
      daemon: Application.get_env(:el, :daemon, El.CLI.Daemon)
    ]
  end
end
