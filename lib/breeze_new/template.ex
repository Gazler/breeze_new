defmodule BreezeNew.Template do
  @moduledoc false

  alias BreezeNew.Config

  @template_root Path.expand("../../priv/templates", __DIR__)

  @common_files [
    {".formatter.exs", "common/.formatter.exs.eex"},
    {".gitignore", "common/.gitignore.eex"},
    {"README.md", "common/README.md.eex"},
    {"mix.exs", "common/mix.exs.eex"},
    {"config/config.exs", "common/config/config.exs.eex"},
    {"config/test.exs", "common/config/test.exs.eex"},
    {"config/prod.exs", "common/config/prod.exs.eex"},
    {"lib/<%= @app_name %>.ex", "common/lib/app.ex.eex"},
    {"lib/<%= @app_name %>/application.ex", "common/lib/application.ex.eex"},
    {"lib/<%= @app_name %>/error_view.ex", "common/lib/error_view.ex.eex"},
    {"test/test_helper.exs", "common/test/test_helper.exs.eex"}
  ]

  @storybook_files [
    {"lib/<%= @app_name %>/components.ex", "common/storybook/components.ex.eex"},
    {"storybook/metric.story.exs", "common/storybook/metric.story.exs.eex"}
  ]

  @starter_files %{
    blank: [
      {"lib/<%= @app_name %>/view.ex", "projects/blank/lib/view.ex.eex"},
      {"test/<%= @app_name %>/view_test.exs", "projects/blank/test/view_test.exs.eex"}
    ],
    counter: [
      {"lib/<%= @app_name %>/view.ex", "projects/counter/lib/view.ex.eex"},
      {"test/<%= @app_name %>/view_test.exs", "projects/counter/test/view_test.exs.eex"}
    ],
    list: [
      {"lib/<%= @app_name %>/view.ex", "projects/list/lib/view.ex.eex"},
      {"test/<%= @app_name %>/view_test.exs", "projects/list/test/view_test.exs.eex"}
    ],
    kitchen_sink: [
      {"lib/<%= @app_name %>/kitchen_sink.ex", "projects/kitchen_sink/lib/kitchen_sink.ex.eex"},
      {"lib/<%= @app_name %>/view.ex", "projects/kitchen_sink/lib/view.ex.eex"},
      {"test/<%= @app_name %>/view_test.exs", "projects/kitchen_sink/test/view_test.exs.eex"}
    ]
  }

  @dev_templates %{
    false => "common/config/dev.exs.eex",
    true => "common/config/dev_timeline.exs.eex"
  }

  @fragment_templates [
    "common/fragments/render_cache_dynamic.config.eex",
    "common/fragments/render_cache_fixed.config.eex",
    "common/fragments/render_cache_dynamic.md.eex",
    "common/fragments/render_cache_fixed.md.eex",
    "common/fragments/theme_cycle_handler.ex.eex",
    "projects/kitchen_sink/fragments/README.md.eex"
  ]

  @template_sources Enum.uniq(
                      Enum.map(
                        @common_files ++
                          @storybook_files ++
                          Enum.flat_map(@starter_files, fn {_starter, files} -> files end),
                        &elem(&1, 1)
                      ) ++
                        Map.values(@dev_templates) ++ @fragment_templates
                    )

  for source <- @template_sources do
    @external_resource Path.join(@template_root, source)
  end

  @templates Map.new(@template_sources, fn source ->
               {source, File.read!(Path.join(@template_root, source))}
             end)

  @spec files(Config.t()) :: %{String.t() => String.t()}
  def files(%Config{} = config) do
    assigns = assigns(config)

    config
    |> file_templates()
    |> Map.new(fn {output, source} ->
      {render_path(output, assigns), render_source(source, assigns)}
    end)
  end

  defp file_templates(%Config{} = config) do
    @common_files
    |> Map.new()
    |> Map.put("config/dev.exs", dev_template(config))
    |> Map.merge(Map.new(Map.fetch!(@starter_files, config.template)))
    |> maybe_add_storybook(config)
  end

  defp maybe_add_storybook(files, %Config{template: template, storybook: true})
       when template != :blank do
    Map.merge(files, Map.new(@storybook_files))
  end

  defp maybe_add_storybook(files, _config), do: files

  defp dev_template(%Config{} = config) do
    Map.fetch!(@dev_templates, config.timeline)
  end

  defp assigns(%Config{} = config) do
    storybook = config.storybook and config.template != :blank

    base = [
      app_name: config.app_name,
      module_name: config.module_name,
      template: config.template,
      cache_size: config.cache_size,
      inspector: config.inspector,
      logger: if(config.inspector, do: :replace, else: false),
      mouse: config.mouse,
      timeline: config.timeline,
      live_reload: config.live_reload,
      storybook: storybook,
      theme_cycle: config.theme_cycle,
      elixir_requirement: elixir_requirement(),
      theme_name: inspect(config.theme),
      initial_theme: inspect(config.theme),
      env_prefix: String.upcase(config.app_name),
      breeze_dep: dependency(:breeze, config.breeze_dep),
      timeline_dependency: timeline_dependency(config),
      live_reload_dependency: live_reload_dependency(config.live_reload),
      extra_applications: extra_applications(config.cache_size),
      theme: theme(config.theme),
      theme_keybinding: theme_keybinding(config.theme_cycle, 9)
    ]

    Keyword.merge(base,
      render_cache_config: render_cache_config(config, base),
      render_cache_readme: render_cache_readme(config, base),
      starter_readme: starter_readme(config, base),
      theme_cycle_handler: theme_cycle_handler(config, base)
    )
  end

  defp dependency(name, {:hex, requirement}), do: inspect({name, requirement})

  defp development_dependency(name, {:hex, requirement}) do
    "{#{inspect(name)}, #{inspect(requirement)}, only: :dev}"
  end

  defp live_reload_dependency(true), do: ",\n      {:file_system, \"~> 1.1\", only: :dev}"
  defp live_reload_dependency(false), do: ""

  defp timeline_dependency(%Config{timeline: true} = config) do
    ",\n      " <> development_dependency(:breeze_timeline, config.breeze_timeline_dep)
  end

  defp timeline_dependency(_config), do: ""

  defp render_cache_config(%Config{cache_size: :dynamic}, assigns) do
    render_fragment("common/fragments/render_cache_dynamic.config.eex", assigns)
  end

  defp render_cache_config(%Config{}, assigns) do
    render_fragment("common/fragments/render_cache_fixed.config.eex", assigns)
  end

  defp render_cache_readme(%Config{cache_size: :dynamic}, assigns) do
    render_fragment("common/fragments/render_cache_dynamic.md.eex", assigns)
  end

  defp render_cache_readme(%Config{}, assigns) do
    render_fragment("common/fragments/render_cache_fixed.md.eex", assigns)
  end

  defp starter_readme(%Config{template: :kitchen_sink}, assigns) do
    render_fragment("projects/kitchen_sink/fragments/README.md.eex", assigns)
  end

  defp starter_readme(_config, _assigns), do: ""

  defp theme_cycle_handler(%Config{theme_cycle: true}, assigns) do
    "common/fragments/theme_cycle_handler.ex.eex"
    |> render_fragment(assigns)
    |> indent(2)
  end

  defp theme_cycle_handler(_config, _assigns), do: ""

  defp extra_applications(:dynamic), do: inspect([:logger, :os_mon])
  defp extra_applications(_size), do: inspect([:logger])

  defp elixir_requirement do
    version = %Version{major: major, minor: minor} = Version.parse!(System.version())

    if version.pre == [] do
      "~> #{major}.#{minor}"
    else
      "~> #{version}"
    end
  end

  defp theme(:system), do: ":system"
  defp theme(theme), do: "Breeze.Theme.builtin(#{inspect(theme)})"

  defp theme_keybinding(true, indentation) do
    "{\"F3\", \"Cycle theme\", &__MODULE__.cycle_theme/2},\n" <>
      String.duplicate(" ", indentation)
  end

  defp theme_keybinding(false, _indentation), do: ""

  defp render_fragment(source, assigns) do
    source
    |> render_source(assigns)
    |> String.trim()
  end

  defp render_source(source, assigns) do
    content = Map.fetch!(@templates, source)
    EEx.eval_string(content, [assigns: assigns], file: source)
  end

  defp render_path(path, assigns), do: EEx.eval_string(path, assigns: assigns)

  defp indent(content, spaces) do
    prefix = String.duplicate(" ", spaces)

    content
    |> String.split("\n")
    |> Enum.map_join("\n", fn
      "" -> ""
      line -> prefix <> line
    end)
  end
end
