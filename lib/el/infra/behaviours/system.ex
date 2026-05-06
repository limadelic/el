defmodule El.Infra.Behaviours.System do
  @callback cmd(binary(), [binary()]) :: {Collectable.t(), exit_status :: non_neg_integer()}
end
