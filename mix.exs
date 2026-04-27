defmodule El.MixProject do
  use Mix.Project

  def project do
    [
      app: :el,
      version: "0.1.86",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      test_paths: ["specs"],
      test_pattern: "**/*.exs",
      test_load_filters: [
        &String.ends_with?(&1, "_test.exs"),
        &String.ends_with?(&1, "_spec.exs")
      ],
      deps: deps(),
      releases: [
        el: [
          steps: [:assemble, :tar],
          overlays: ["rel/overlays"]
        ]
      ],
      escript: [main_module: El.CLI],
      package: package()
    ]
  end

  defp package do
    [
      name: "el",
      description: "CLI for managing headless Claude Code sessions",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/limadelic/el"
      },
      source_url: "https://github.com/limadelic/el"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    app_config = [extra_applications: [:logger]]

    case Mix.env() do
      :test -> app_config
      _ -> Keyword.put(app_config, :mod, {El.Application, []})
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:claude_code, "~> 0.36"},
      {:mox, "~> 1.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
