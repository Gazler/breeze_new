defmodule BreezeNew.MixProject do
  use Mix.Project

  @breeze_requirement "~> 0.5.0"
  @back_breeze_requirement "~> 0.4.4"

  def project do
    [
      app: :breeze_new,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: BreezeNew.CLI],
      aliases: aliases(),
      deps: deps()
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
      {:back_breeze, @back_breeze_requirement}
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
end
