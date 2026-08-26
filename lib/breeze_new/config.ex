defmodule BreezeNew.Config do
  @moduledoc "Configuration shared by the TUI and non-interactive generator."

  @breeze_requirement "~> 0.5.0"
  @templates [:blank, :counter]
  @themes [
    :dracula,
    :commander,
    :gruvbox,
    :catppuccin,
    :nord,
    :solarized_light,
    :solarized_dark,
    :system
  ]

  @enforce_keys [:app_name, :module_name, :target]
  defstruct app_name: nil,
            module_name: nil,
            target: nil,
            template: :counter,
            theme: :gruvbox,
            theme_cycle: true,
            cache_size: 256,
            deps_get: false,
            mouse: true,
            inspector: true,
            timeline: false,
            live_reload: true,
            storybook: true,
            init_git: true,
            commit_message: "Initial commit",
            breeze_dep: {:hex, @breeze_requirement},
            breeze_timeline_dep: {:hex, "~> 0.1.0"}

  @type t :: %__MODULE__{
          app_name: String.t(),
          module_name: String.t(),
          target: String.t(),
          template: :blank | :counter,
          theme:
            :dracula
            | :commander
            | :gruvbox
            | :catppuccin
            | :nord
            | :solarized_light
            | :solarized_dark
            | :system,
          theme_cycle: boolean(),
          cache_size: pos_integer() | :dynamic,
          deps_get: boolean(),
          mouse: boolean(),
          inspector: boolean(),
          timeline: boolean(),
          live_reload: boolean(),
          storybook: boolean(),
          init_git: boolean(),
          commit_message: String.t(),
          breeze_dep: {:hex, String.t()},
          breeze_timeline_dep: {:hex, String.t()}
        }

  @spec templates() :: [atom()]
  def templates, do: @templates

  @spec themes() :: [atom()]
  def themes, do: @themes

  @doc false
  def put_timeline(%__MODULE__{} = config, enabled) when is_boolean(enabled) do
    %{config | timeline: enabled}
  end

  @doc false
  @spec parse_cache_size(term()) :: {:ok, pos_integer() | :dynamic} | {:error, String.t()}
  def parse_cache_size(:dynamic), do: {:ok, :dynamic}
  def parse_cache_size(size) when is_integer(size) and size > 0, do: {:ok, size}

  def parse_cache_size(value) when is_binary(value) do
    value = String.trim(value)

    cond do
      String.downcase(value) == "dynamic" ->
        {:ok, :dynamic}

      true ->
        case Integer.parse(value) do
          {size, ""} when size > 0 -> {:ok, size}
          _other -> invalid_cache_size()
        end
    end
  end

  def parse_cache_size(_value), do: invalid_cache_size()

  @spec new(String.t(), keyword()) :: {:ok, t()} | {:error, String.t()}
  def new(name, opts \\ []) when is_binary(name) do
    app_name = name |> Path.basename() |> String.trim()
    target = Path.expand(Keyword.get(opts, :target, name))
    allow_empty? = Keyword.get(opts, :allow_empty, false)
    inspector = Keyword.get(opts, :inspector, true)
    timeline = Keyword.get(opts, :timeline, false)

    with :ok <- validate_initial_app_name(app_name, allow_empty?),
         {:ok, template} <- choice(:template, Keyword.get(opts, :template, :counter), @templates),
         {:ok, theme} <- choice(:theme, Keyword.get(opts, :theme, :gruvbox), @themes),
         {:ok, cache_size} <- parse_cache_size(Keyword.get(opts, :cache_size, 256)),
         :ok <- validate_timeline_inspector(timeline, inspector) do
      {:ok,
       %__MODULE__{
         app_name: app_name,
         module_name: Macro.camelize(app_name),
         target: target,
         template: template,
         theme: theme,
         theme_cycle: Keyword.get(opts, :theme_cycle, true),
         cache_size: cache_size,
         deps_get: Keyword.get(opts, :deps_get, false),
         mouse: Keyword.get(opts, :mouse, true),
         inspector: inspector,
         timeline: timeline,
         live_reload: Keyword.get(opts, :live_reload, true),
         storybook: template != :blank and Keyword.get(opts, :storybook, true),
         init_git: Keyword.get(opts, :init_git, true),
         commit_message: Keyword.get(opts, :commit_message, "Initial commit"),
         breeze_dep: Keyword.get(opts, :breeze_dep, {:hex, @breeze_requirement}),
         breeze_timeline_dep: Keyword.get(opts, :breeze_timeline_dep, {:hex, "~> 0.1.0"})
       }}
    end
  end

  defp validate_initial_app_name("", true), do: :ok
  defp validate_initial_app_name(name, _allow_empty?), do: validate_app_name(name)

  @spec validate(t()) :: :ok | {:error, String.t()}
  def validate(%__MODULE__{} = config) do
    with :ok <- validate_app_name(config.app_name),
         :ok <- validate_module_name(config),
         :ok <- validate_target(config.target),
         :ok <- validate_member(:template, config.template, @templates),
         :ok <- validate_member(:theme, config.theme, @themes),
         :ok <- validate_cache_size(config.cache_size),
         :ok <- validate_booleans(config),
         :ok <- validate_timeline_inspector(config.timeline, config.inspector),
         :ok <- validate_storybook(config),
         :ok <- validate_dependency(:breeze, config.breeze_dep),
         :ok <- validate_dependency(:breeze_timeline, config.breeze_timeline_dep),
         :ok <- validate_commit_message(config) do
      :ok
    end
  end

  defp validate_app_name(name) when is_binary(name) do
    if Regex.match?(~r/^[a-z][a-z0-9_]*$/, name) do
      :ok
    else
      {:error,
       "project name must start with a lowercase letter and contain only lowercase letters, numbers, and underscores"}
    end
  end

  defp validate_app_name(_name), do: {:error, "project name must be a string"}

  defp validate_module_name(%{app_name: app_name, module_name: module_name}) do
    expected = Macro.camelize(app_name)

    if module_name == expected do
      :ok
    else
      {:error, "module name must match the project name (expected #{expected})"}
    end
  end

  defp validate_target(target) when is_binary(target) and target != "" do
    cond do
      File.exists?(target) ->
        {:error, "target already exists: #{target}"}

      not File.exists?(Path.dirname(target)) ->
        {:error, "parent directory does not exist: #{Path.dirname(target)}"}

      true ->
        :ok
    end
  end

  defp validate_target(_target), do: {:error, "target must be a non-empty path"}

  defp validate_booleans(config) do
    invalid =
      Enum.reject(
        [
          :theme_cycle,
          :deps_get,
          :mouse,
          :inspector,
          :timeline,
          :live_reload,
          :storybook,
          :init_git
        ],
        &is_boolean(Map.fetch!(config, &1))
      )

    case invalid do
      [] -> :ok
      fields -> {:error, "expected boolean value for #{Enum.join(fields, ", ")}"}
    end
  end

  defp validate_storybook(%{template: :blank, storybook: true}),
    do: {:error, "Storybook is not available for the blank starter"}

  defp validate_storybook(_config), do: :ok

  defp validate_timeline_inspector(true, false),
    do: {:error, "Inspector must be enabled when Timeline is enabled"}

  defp validate_timeline_inspector(_timeline, _inspector), do: :ok

  defp validate_cache_size(:dynamic), do: :ok
  defp validate_cache_size(size) when is_integer(size) and size > 0, do: :ok
  defp validate_cache_size(_size), do: invalid_cache_size()

  defp invalid_cache_size,
    do: {:error, ~s(cache size must be a positive integer in MB or "dynamic")}

  defp validate_dependency(name, {:hex, requirement}) when is_binary(requirement) do
    case Version.parse_requirement(requirement) do
      {:ok, _requirement} ->
        :ok

      :error ->
        {:error, "invalid #{dependency_label(name)} version requirement: #{inspect(requirement)}"}
    end
  end

  defp validate_dependency(name, _dependency) do
    {:error, "#{dependency_label(name)} dependency must be {:hex, requirement}"}
  end

  defp dependency_label(:breeze), do: "Breeze"
  defp dependency_label(:breeze_timeline), do: "Breeze Timeline"

  defp validate_commit_message(%{init_git: true, commit_message: message})
       when is_binary(message) do
    if String.trim(message) == "" do
      {:error, "commit message cannot be empty when Initialize Git is enabled"}
    else
      :ok
    end
  end

  defp validate_commit_message(%{init_git: true}),
    do: {:error, "commit message must be a string"}

  defp validate_commit_message(_config), do: :ok

  defp choice(name, value, choices) do
    normalized =
      if is_binary(value), do: Enum.find(choices, &(Atom.to_string(&1) == value)), else: value

    case validate_member(name, normalized, choices) do
      :ok -> {:ok, normalized}
      {:error, _} -> invalid_member(name, value, choices)
    end
  end

  defp validate_member(name, value, choices) do
    if value in choices do
      :ok
    else
      invalid_member(name, value, choices)
    end
  end

  defp invalid_member(name, value, choices) do
    {:error, "unknown #{name} #{inspect(value)}; expected one of #{Enum.join(choices, ", ")}"}
  end
end
