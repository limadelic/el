defmodule El.DetsBackend.Spec do
  use ExUnit.Case

  describe "foldl/3" do
    test "accumulates entries with fold function" do
      table_name = :dets_backend_test_table
      file = "/tmp/dets_backend_test_#{System.unique_integer()}.dets"

      on_exit(fn ->
        :dets.close(table_name)
        File.rm(file)
      end)

      {:ok, ^table_name} = :dets.open_file(table_name, type: :bag, file: ~c"#{file}")
      :dets.insert(table_name, {:a, "x"})
      :dets.insert(table_name, {:b, "y"})

      result = El.DetsBackend.foldl(table_name, [], fn {key, _val}, acc -> [key | acc] end)

      assert Enum.sort(result) == [:a, :b]
    end
  end
end
