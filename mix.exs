defmodule El.MixProject do
  use Mix.Project

  def project do
    [
      app: :el,
      version: "0.1.36",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      test_paths: ["specs"],
      test_pattern: "**/*.exs",
      test_load_filters: [
        &String.ends_with?(&1, "_test.exs"),
        &String.ends_with?(&1, "_spec.exs")
      ],
      deps: deps(),
      escript: [main_module: El.CLI],
      package: package(),
      releases: releases()
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
    [
      extra_applications: [:logger],
      mod: {El.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:claude_code, "~> 0.36"},
      {:burrito, "~> 1.0"},
      {:cabbage, "~> 0.4", only: :test},
      {:mimic, "~> 1.7", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp releases do
    [
      el: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos_arm64: [os: :darwin, cpu: :aarch64]
          ]
        ]
      ]
    ]
  end
end
