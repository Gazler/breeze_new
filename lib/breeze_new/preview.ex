defmodule BreezeNew.Preview do
  @moduledoc false

  alias BreezeNew.{Config, Template}

  @templates [:blank, :counter, :list, :kitchen_sink]
  @default_app_name "breeze_new_preview"

  defstruct [:config, :view, modules: []]

  @type t :: %__MODULE__{
          config: Config.t(),
          view: module(),
          modules: [module()]
        }

  @doc false
  @spec templates() :: [atom()]
  def templates, do: @templates

  @doc false
  @spec prepare(atom() | String.t(), keyword()) :: {:ok, t()} | {:error, String.t()}
  def prepare(template, opts \\ []) do
    with {:ok, template} <- normalize_template(template),
         {:ok, config} <- preview_config(template, opts),
         {:ok, modules} <- compile_runtime_files(config) do
      {:ok,
       %__MODULE__{
         config: config,
         view: Module.concat([config.module_name, "View"]),
         modules: modules
       }}
    end
  end

  @doc false
  @spec run(atom() | String.t(), keyword()) :: :ok | {:error, String.t()}
  def run(template, opts \\ []) do
    runner = Keyword.get(opts, :runner, &Breeze.Server.run/1)

    with {:ok, _applications} <- ensure_breeze_started(),
         {:ok, preview} <- prepare(template, opts) do
      try do
        preview
        |> server_options()
        |> runner.()
        |> normalize_runner_result()
      after
        unload(preview)
      end
    end
  end

  @doc false
  @spec server_options(t()) :: keyword()
  def server_options(%__MODULE__{config: config, view: view}) do
    [
      view: view,
      theme: preview_theme(config.theme),
      mouse: config.mouse,
      inspector: [remote: false],
      logger: :replace,
      reload: false,
      global_keybindings: [
        {"F3", "Cycle theme", &Breeze.View.cycle_theme/2},
        {"q", "Quit", fn _event, term -> {:stop, term} end}
      ]
    ]
  end

  @doc false
  @spec unload(t()) :: :ok
  def unload(%__MODULE__{modules: modules}) do
    modules
    |> Enum.reverse()
    |> Enum.each(fn module ->
      :code.purge(module)
      :code.delete(module)
    end)

    :ok
  end

  defp normalize_template(:ssh),
    do: {:error, "the SSH starter is not available in preview mode"}

  defp normalize_template(template) when template in @templates, do: {:ok, template}

  defp normalize_template(template) when is_binary(template) do
    normalized = String.replace(template, "-", "_")

    case Enum.find(@templates, &(Atom.to_string(&1) == normalized)) do
      nil when normalized == "ssh" -> normalize_template(:ssh)
      nil -> invalid_template(template)
      template -> {:ok, template}
    end
  end

  defp normalize_template(template), do: invalid_template(template)

  defp invalid_template(template) do
    available = Enum.map_join(@templates, ", ", &Atom.to_string/1)
    {:error, "unknown preview starter #{inspect(template)}; choose one of: #{available}"}
  end

  defp preview_config(template, opts) do
    app_name = Keyword.get(opts, :app_name, @default_app_name)

    Config.new(app_name,
      target: Keyword.get(opts, :target, app_name),
      template: template,
      theme: Keyword.get(opts, :theme, :gruvbox),
      mouse: Keyword.get(opts, :mouse, true),
      inspector: true,
      timeline: false,
      live_reload: false,
      storybook: true,
      deps_get: false,
      init_git: false
    )
  end

  defp compile_runtime_files(config) do
    files = Template.files(config)
    purge_candidate_modules(config)

    modules =
      config
      |> runtime_paths(files)
      |> Enum.flat_map(fn path ->
        files
        |> Map.fetch!(path)
        |> Code.compile_string("breeze_new_preview/#{path}")
        |> Enum.map(&elem(&1, 0))
      end)

    {:ok, modules}
  rescue
    error ->
      purge_candidate_modules(config)
      {:error, "could not compile the preview: #{Exception.message(error)}"}
  end

  defp runtime_paths(config, files) do
    root = "lib/#{config.app_name}"

    [
      "#{root}/components.ex",
      "#{root}/kitchen_sink.ex",
      "#{root}/view.ex"
    ]
    |> Enum.filter(&Map.has_key?(files, &1))
  end

  defp purge_candidate_modules(config) do
    Enum.each(~w(Components KitchenSink View), fn suffix ->
      module = Module.concat([config.module_name, suffix])
      :code.purge(module)
      :code.delete(module)
    end)
  end

  defp ensure_breeze_started do
    case Application.ensure_all_started(:breeze) do
      {:ok, applications} -> {:ok, applications}
      {:error, reason} -> {:error, "could not start Breeze: #{inspect(reason)}"}
    end
  end

  defp preview_theme(:system), do: :system
  defp preview_theme(theme), do: Breeze.Theme.builtin(theme)

  defp normalize_runner_result(:ok), do: :ok

  defp normalize_runner_result({:error, reason}),
    do: {:error, "preview exited: #{inspect(reason)}"}

  defp normalize_runner_result(other),
    do: {:error, "preview returned an unexpected result: #{inspect(other)}"}
end
