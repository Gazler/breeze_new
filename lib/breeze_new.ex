defmodule BreezeNew do
  @moduledoc """
  Generates a ready-to-run Breeze application.

  Most users invoke the `breeze_new` escript. The public API is useful for
  automation and for testing custom wrappers around the generator.
  """

  alias BreezeNew.{Config, Generator}

  @doc "Generates a project from a validated `BreezeNew.Config`."
  @spec generate(Config.t(), keyword()) :: Generator.result()
  defdelegate generate(config, opts \\ []), to: Generator
end
