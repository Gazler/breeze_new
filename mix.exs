defmodule BreezeNew.MixProject do
  use Mix.Project

  @breeze_version "0.5.1"
  @breeze_requirement "~> #{@breeze_version}"
  @back_breeze_requirement "~> 0.4.4"

  def project do
    [
      app: :breeze_new,
      version: @breeze_version,
      description: "A TUI project generator for Breeze applications",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: BreezeNew.CLI],
      aliases: aliases(),
      package: package(),
      deps: deps(),
      docs: [
        source_ref: "v#{@breeze_version}",
        extras: [
          "README.md"
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :eex],
      mod: {BreezeNew.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:breeze, @breeze_requirement},
      {:back_breeze, @back_breeze_requirement},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [run: [&run_cli/1]]
  end

  defp run_cli(args) do
    Mix.Task.run("app.start")
    BreezeNew.CLI.main(drop_separator(args))
  end

  defp drop_separator(["--" | args]), do: args
  defp drop_separator(args), do: args

  defp package do
    [
      files: ~w(lib priv mix.exs README.md LICENSE.md),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Gazler/breeze_new"}
    ]
  end
end
