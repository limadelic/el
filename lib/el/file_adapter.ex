defmodule El.FileAdapter do
  @callback open(path :: charlist(), options :: list()) :: {:ok, term()} | {:error, term()}
  @callback write(io_device :: term(), data :: binary()) :: :ok | {:error, term()}
  @callback read(io_device :: term(), length :: pos_integer()) ::
              {:ok, binary()} | {:error, term()}
end
