defmodule BreezeNew.CLI do
  @moduledoc "Command-line entrypoint for the `breeze_new` escript."

  alias BreezeNew.{Config, Generator, Wizard}

  @version Mix.Project.config()[:version]
  @switches [
    help: :boolean,
    version: :boolean,
    no_tui: :boolean,
    template: :string,
    theme: :string,
    theme_cycle: :boolean,
    cache_size: :string,
    deps_get: :boolean,
    mouse: :boolean,
    inspector: :boolean,
    timeline: :boolean,
    live_reload: :boolean,
    storybook: :boolean,
    git: :boolean,
    commit_message: :string
  ]
  @aliases [h: :help, v: :version]

  @spec main([String.t()]) :: :ok
  def main(argv) do
    case parse(argv) do
      {:help, text} ->
        IO.puts(text)

      {:version, version} ->
        IO.puts(version)

      {:error, message} ->
        IO.puts(:stderr, "error: #{message}\n\n#{usage()}")
        System.halt(1)

      {:ok, config, tui?} ->
        result = maybe_run_wizard(config, tui?)
        prepare_terminal_output(tui?)
        generate(result, tui?)
    end
  end

  @doc false
  def parse(argv) do
    case OptionParser.parse(argv, strict: @switches, aliases: @aliases) do
      {opts, args, []} -> parse_options(opts, args)
      {_opts, _args, invalid} -> {:error, invalid_options(invalid)}
    end
  end

  defp parse_options(opts, args) do
    cond do
      Keyword.get(opts, :help, false) -> {:help, usage()}
      Keyword.get(opts, :version, false) -> {:version, @version}
      true -> parse_project_options(opts, args)
    end
  end

  defp parse_project_options(opts, [name]), do: build_config(name, opts)

  defp parse_project_options(opts, []) do
    if Keyword.get(opts, :no_tui, false) do
      {:error, "expected a project name when --no-tui is used"}
    else
      build_config("", Keyword.put(opts, :allow_empty, true))
    end
  end

  defp parse_project_options(_opts, _args), do: {:error, "expected at most one project name"}

  defp build_config(name, opts) do
    config_opts =
      [
        template: Keyword.get(opts, :template, :counter),
        theme: Keyword.get(opts, :theme, :gruvbox),
        theme_cycle: Keyword.get(opts, :theme_cycle, true),
        cache_size: Keyword.get(opts, :cache_size, 256),
        deps_get: Keyword.get(opts, :deps_get, false),
        mouse: Keyword.get(opts, :mouse, true),
        inspector: Keyword.get(opts, :inspector, true),
        timeline: Keyword.get(opts, :timeline, false),
        live_reload: Keyword.get(opts, :live_reload, true),
        init_git: Keyword.get(opts, :git, true),
        commit_message: Keyword.get(opts, :commit_message, "Initial commit"),
        allow_empty: Keyword.get(opts, :allow_empty, false)
      ]
      |> maybe_put_storybook(opts)

    case Config.new(name, config_opts) do
      {:ok, config} -> {:ok, config, !Keyword.get(opts, :no_tui, false)}
      {:error, message} -> {:error, message}
    end
  end

  defp maybe_run_wizard(config, false), do: {:generate, config}

  defp maybe_run_wizard(config, true) do
    result =
      Breeze.Server.run(
        view: Wizard,
        start_opts: [config: config, caller: self()],
        theme: wizard_theme(config.theme),
        mouse: true,
        global_keybindings: []
      )

    case result do
      :ok ->
        receive do
          {:breeze_new, result} -> result
        after
          1_000 -> {:error, "wizard exited without a result"}
        end

      {:error, reason} ->
        {:error, "could not start the wizard: #{inspect(reason)}"}
    end
  end

  defp generate(:cancel, tui?) do
    write_line(:stdio, "Project creation cancelled.", tui?)
  end

  defp generate({:error, message}, tui?) do
    write_line(:stderr, "error: #{message}", tui?)
    System.halt(1)
  end

  defp generate({:generate, config}, tui?) do
    case Generator.generate(config) do
      {:ok, result} ->
        write_line(:stdio, "Created #{result.target}", tui?)
        Enum.each(result.warnings, &write_line(:stderr, "warning: #{&1}", tui?))

        deps_step = if config.deps_get, do: "", else: "\n  mix deps.get"

        write_line(
          :stdio,
          "\nNext steps:\n  cd #{Path.relative_to_cwd(result.target)}#{deps_step}\n  mix run --no-halt#{timeline_run_step(config)}",
          tui?
        )

      {:error, message} ->
        write_line(:stderr, "error: #{message}", tui?)
        System.halt(1)
    end
  end

  defp prepare_terminal_output(true), do: IO.write("\r\e[0m")
  defp prepare_terminal_output(false), do: :ok

  defp timeline_run_step(%Config{timeline: true}) do
    "\n\nInspect and rewind it from another terminal:\n  mix breeze.inspector"
  end

  defp timeline_run_step(_config), do: ""

  defp write_line(device, text, tui?), do: IO.write(device, format_output(text, tui?))

  @doc false
  def format_output(text, true), do: String.replace(text, "\n", "\r\n") <> "\r\n"
  def format_output(text, false), do: text <> "\n"

  defp wizard_theme(:system), do: :system
  defp wizard_theme(theme), do: Breeze.Theme.builtin(theme)

  defp invalid_options(invalid) do
    invalid
    |> Enum.map_join(", ", fn {option, value} ->
      if is_nil(value), do: option, else: "#{option}=#{value}"
    end)
    |> then(&"unknown or invalid option(s): #{&1}")
  end

  defp usage do
    """
    Usage: breeze_new [PROJECT] [options]

    Opens a TUI for configuring a new Breeze application. PROJECT is optional
    unless --no-tui is used.

    Options:
      --template blank|counter|list
                                    Starter application (default: counter)
      --theme THEME                 Initial theme: dracula, commander, gruvbox,
                                    catppuccin, nord, solarized_light,
                                    solarized_dark, or system
                                    (default: gruvbox)
      --[no-]theme-cycle            Bind F3 to cycle themes (default: enabled)
      --cache-size MB|dynamic       Render cache size in MB, or dynamic via os_mon
                                    (default: 256)
      --[no-]deps-get               Fetch project dependencies (default: disabled)
      --[no-]mouse                  Enable mouse input (default: enabled)
      --[no-]inspector              Configure development inspector (default: enabled)
      --[no-]timeline               Add the development timeline (default: disabled)
      --[no-]live-reload            Reload changed code in development (default: enabled)
      --[no-]storybook              Generate a component Storybook (enabled for example starters)
      --[no-]git                    Initialize and commit a Git repository (default: enabled)
      --commit-message MESSAGE      Initial Git commit message (default: Initial commit)
      --no-tui                      Generate directly from command-line options
      -h, --help                    Show this help
      -v, --version                 Show the version
    """
  end

  defp maybe_put_storybook(config_opts, opts) do
    if Keyword.has_key?(opts, :storybook) do
      Keyword.put(config_opts, :storybook, Keyword.fetch!(opts, :storybook))
    else
      config_opts
    end
  end
end
