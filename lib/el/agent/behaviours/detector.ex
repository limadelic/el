defmodule El.Agent.Behaviours.Detector do
  @callback detect_agent(term()) :: term()
end
