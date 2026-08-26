defmodule Mix.Tasks.BreezeNew.Preview do
  use Mix.Task

  @shortdoc "Runs a starter in memory without generating a project"
  @requirements ["app.config"]

  @moduledoc """
  Runs a starter directly from the current templates.

      mix breeze_new.preview counter

  Available starters are `blank` and `counter`.
  Preview modules are compiled in memory and unloaded when the view exits; no
  project files are created. Press `F3` to cycle themes, `F4` for the local
  inspector, and `q` to quit.
  """

  @impl Mix.Task
  def run([template]) do
    Mix.shell().info("Previewing #{template}; press q to quit.")

    case BreezeNew.Preview.run(template) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end

  def run(_args) do
    Mix.raise("expected one starter: mix breeze_new.preview blank|counter")
  end
end
