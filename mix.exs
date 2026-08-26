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
end
