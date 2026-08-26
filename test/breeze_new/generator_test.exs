defmodule BreezeNew.GeneratorTest do
  use ExUnit.Case, async: true

  alias BreezeNew.{Config, Generator, Template}

  for template <- Config.templates() do
    @template template

    test "generates the #{@template} starter" do
      target = tmp_target(Atom.to_string(@template))
      on_exit(fn -> File.rm_rf(target) end)

      config = config!(target, template: @template)
      assert {:ok, result} = Generator.generate(config)

      assert result.target == target
      assert result.warnings == []
      assert ".formatter.exs" in result.files
      assert "lib/sample_app/view.ex" in result.files

      mix_file = File.read!(Path.join(target, "mix.exs"))
      %Version{major: elixir_major, minor: elixir_minor} = Version.parse!(System.version())
      root_config = File.read!(Path.join(target, "config/config.exs"))
      view_file = File.read!(Path.join(target, "lib/sample_app/view.ex"))
      application_file = File.read!(Path.join(target, "lib/sample_app/application.ex"))
      error_view = File.read!(Path.join(target, "lib/sample_app/error_view.ex"))
      dev_config = File.read!(Path.join(target, "config/dev.exs"))
      prod_config = File.read!(Path.join(target, "config/prod.exs"))
      readme = File.read!(Path.join(target, "README.md"))
      formatter = File.read!(Path.join(target, ".formatter.exs"))

      for relative_path <- result.files,
          String.ends_with?(relative_path, [".ex", ".exs"]) do
        refute File.read!(Path.join(target, relative_path)) =~ ~r/@(?:spec|type|typedoc)\b/,
               "expected #{relative_path} not to contain a typespec"
      end

      server_options_file = application_file

      assert mix_file =~ "defmodule SampleApp.MixProject"
      assert [_, elixir_requirement] = Regex.run(~r/elixir: "([^"]+)"/, mix_file)
      assert elixir_requirement =~ "#{elixir_major}.#{elixir_minor}"
      assert Version.match?(System.version(), elixir_requirement)
      assert mix_file =~ ~s({:breeze, "~> 0.5.0"})
      refute mix_file =~ "path:"
      assert mix_file =~ "extra_applications: [:logger]"
      refute mix_file =~ ":os_mon"
      assert root_config =~ "config :back_breeze"
      assert root_config =~ "render_cache_max_memory_bytes: 256 * 1_024 * 1_024"
      refute root_config =~ "config :os_mon"
      assert readme =~ "## Render cache"
      assert readme =~ "render cache is capped at 256 MB"
      assert view_file =~ "defmodule SampleApp.View"
      assert view_file =~ expected_marker(@template)

      if @template == :blank do
        refute view_file =~ ".keybinding_bar"
        refute view_file =~ ".panel"
        refute "lib/sample_app/components.ex" in result.files
        refute "storybook/metric.story.exs" in result.files
        refute readme =~ "mix breeze.storybook"
        refute dev_config =~ "storybook_theme"
      else
        assert view_file =~
                 ~s(class="inline width-full height-1 overflow-hidden bg-panel padding-left-1 padding-right-1")

        component = File.read!(Path.join(target, "lib/sample_app/components.ex"))
        story = File.read!(Path.join(target, "storybook/metric.story.exs"))

        assert "lib/sample_app/components.ex" in result.files
        assert "storybook/metric.story.exs" in result.files
        assert component =~ "defmodule SampleApp.Components"
        assert component =~ "attr :label, :string, required: true"
        refute component =~ "attr("
        assert component =~ "def metric(assigns)"
        assert story =~ "defmodule SampleApp.Stories.MetricStory"
        assert story =~ "import SampleApp.Components"
        assert view_file =~ "import SampleApp.Components"
        assert view_file =~ ".metric"
        assert readme =~ "mix breeze.storybook"
        assert dev_config =~ "storybook_theme: :gruvbox"
        assert {:ok, _ast} = Code.string_to_quoted(component)
        assert {:ok, _ast} = Code.string_to_quoted(story)
      end

      assert formatter =~ "{config,lib,test,storybook}/**/*.{ex,exs}"
      assert formatter =~ "plugins: [Breeze.HTMLFormatter]"
      assert formatter =~ "import_deps: [:breeze]"
      assert formatter =~ "locals_without_parens = [attr: 2, attr: 3, slot: 1, slot: 2]"
      assert formatter =~ "locals_without_parens: locals_without_parens"

      assert server_options_file =~ ~s({"F3", "Cycle theme")
      assert server_options_file =~ "&__MODULE__.cycle_theme/2"
      assert server_options_file =~ "def cycle_theme(event, term)"
      assert server_options_file =~ "_name -> :gruvbox"
      assert server_options_file =~ ~s({"q", "Quit")
      assert server_options_file =~ "reload: Application.get_env(:sample_app, :reload, false)"
      assert server_options_file =~ "render_errors: Application.get_env"
      refute server_options_file =~ "F10"
      assert dev_config =~ "reload: true"
      assert dev_config =~ "render_errors: [view: Breeze.ErrorView]"
      assert prod_config =~ "inspector: false"
      assert prod_config =~ "logger: false"
      assert prod_config =~ "reload: false"
      assert prod_config =~ "view: SampleApp.ErrorView"
      assert prod_config =~ ~s(keybindings: [{"q", "Quit", :stop}])
      refute prod_config =~ "Breeze.ErrorView"
      assert error_view =~ "defmodule SampleApp.ErrorView"
      assert error_view =~ "Something went wrong."
      refute error_view =~ "@stacktrace"
      refute error_view =~ "@reason"
      assert "lib/sample_app/error_view.ex" in result.files
      assert mix_file =~ ~s({:file_system, "~> 1.1", only: :dev})
      assert {:ok, _ast} = Code.string_to_quoted(application_file)
      assert {:ok, _ast} = Code.string_to_quoted(error_view)
      assert {:ok, _ast} = Code.string_to_quoted(server_options_file)

      assert IO.iodata_to_binary(Code.format_string!(application_file)) <> "\n" ==
               application_file

      assert IO.iodata_to_binary(Code.format_string!(mix_file)) <> "\n" == mix_file

      assert IO.iodata_to_binary(Code.format_string!(root_config)) <> "\n" == root_config

      assert IO.iodata_to_binary(Code.format_string!(error_view)) <> "\n" == error_view

      assert IO.iodata_to_binary(Code.format_string!(dev_config)) <> "\n" == dev_config

      assert IO.iodata_to_binary(Code.format_string!(server_options_file)) <> "\n" ==
               server_options_file

      refute mix_file =~ ":breeze_timeline"
      refute dev_config =~ "Breeze.Timeline"
      refute readme =~ "## Timeline inspector"
    end
  end

  for template <- Config.templates() do
    @dynamic_cache_template template

    test "can dynamically size the render cache in the #{@dynamic_cache_template} starter" do
      target = tmp_target("#{@dynamic_cache_template}_dynamic_cache")
      on_exit(fn -> File.rm_rf(target) end)

      config = config!(target, template: @dynamic_cache_template, cache_size: :dynamic)
      assert {:ok, _result} = Generator.generate(config)

      mix_file = File.read!(Path.join(target, "mix.exs"))
      root_config = File.read!(Path.join(target, "config/config.exs"))
      readme = File.read!(Path.join(target, "README.md"))

      assert mix_file =~ "extra_applications: [:logger, :os_mon]"
      assert root_config =~ "config :back_breeze, render_cache_max_memory_bytes: :auto"
      assert root_config =~ "config :os_mon"
      assert root_config =~ "start_cpu_sup: false"
      assert root_config =~ "start_disksup: false"
      assert readme =~ "sizes its render cache dynamically"
      assert readme =~ "starts OTP's `:os_mon` service"

      assert IO.iodata_to_binary(Code.format_string!(mix_file)) <> "\n" == mix_file
      assert IO.iodata_to_binary(Code.format_string!(root_config)) <> "\n" == root_config
    end
  end

  test "generated projects target the supported Breeze release by default" do
    target = tmp_target("published_breeze")
    on_exit(fn -> File.rm_rf(target) end)

    {:ok, config} = Config.new("sample_app", target: target, init_git: false)
    assert {:ok, _result} = Generator.generate(config)

    mix_file = File.read!(Path.join(target, "mix.exs"))

    assert mix_file =~ ~s({:breeze, "~> 0.5.0"})
    refute mix_file =~ "path:"
  end

  test "can set a custom fixed render cache size" do
    target = tmp_target("fixed_cache")
    on_exit(fn -> File.rm_rf(target) end)

    assert {:ok, _result} = Generator.generate(config!(target, cache_size: 512))

    root_config = File.read!(Path.join(target, "config/config.exs"))
    readme = File.read!(Path.join(target, "README.md"))

    assert root_config =~ "render_cache_max_memory_bytes: 512 * 1_024 * 1_024"
    assert readme =~ "render cache is capped at 512 MB"
  end

  for template <- Config.templates() do
    @timeline_template template

    test "can add Timeline to the #{@timeline_template} starter" do
      target = tmp_target("#{@timeline_template}_timeline")
      on_exit(fn -> File.rm_rf(target) end)

      config = config!(target, template: @timeline_template, timeline: true)
      assert {:ok, _result} = Generator.generate(config)

      mix_file = File.read!(Path.join(target, "mix.exs"))
      dev_config = File.read!(Path.join(target, "config/dev.exs"))
      prod_config = File.read!(Path.join(target, "config/prod.exs"))
      readme = File.read!(Path.join(target, "README.md"))

      assert mix_file =~ ~s({:breeze_timeline, "~> 0.1.0", only: :dev})
      assert dev_config =~ "{Breeze.Timeline.Page,"
      assert dev_config =~ "every: 1"
      assert dev_config =~ "limit: 120"
      assert dev_config =~ "include: [:frame, :inspector]"
      assert readme =~ "## Timeline inspector"
      assert readme =~ "mix breeze.inspector"
      assert readme =~ "Timeline recording is disabled in production."
      refute prod_config =~ "Breeze.Timeline"

      assert IO.iodata_to_binary(Code.format_string!(mix_file)) <> "\n" == mix_file
      assert IO.iodata_to_binary(Code.format_string!(dev_config)) <> "\n" == dev_config
    end
  end

  for template <- Config.templates() do
    @theme_cycle_template template

    test "F3 advances from the selected theme in the #{@theme_cycle_template} starter" do
      suffix = System.unique_integer([:positive])
      app_name = "theme_cycle_#{@theme_cycle_template}_#{suffix}"
      target = tmp_target(app_name)

      {:ok, config} =
        Config.new(app_name,
          target: target,
          template: @theme_cycle_template,
          storybook: false,
          init_git: false
        )

      files = Template.files(config)
      module_name = Macro.camelize(app_name)
      view_module = Module.concat([module_name, "View"])

      callback_module = Module.concat([module_name, "Application"])

      assert [{^view_module, _bytecode}] =
               Code.compile_string(files["lib/#{app_name}/view.ex"])

      callback_path = "lib/#{app_name}/application.ex"

      assert [{^callback_module, _bytecode}] =
               Code.compile_string(files[callback_path])

      handler = Function.capture(callback_module, :cycle_theme, 2)

      session =
        Breeze.Test.start!(view_module,
          size: {80, 20},
          theme: Breeze.Theme.builtin(:gruvbox),
          global_keybindings: [{"F3", "Cycle theme", handler}]
        )

      on_exit(fn -> Breeze.Test.stop(session) end)

      assert get_in(Breeze.Test.metadata(session).assigns, [:breeze, :theme, :name]) ==
               "gruvbox-dark"

      Breeze.Test.input(session, "F3")

      assert get_in(Breeze.Test.metadata(session).assigns, [:breeze, :theme, :name]) == :nord

      Breeze.Test.input(session, "F3")

      assert get_in(Breeze.Test.metadata(session).assigns, [:breeze, :theme, :name]) ==
               :solarized_light
    end
  end

  test "does not overwrite an existing target" do
    target = tmp_target("existing")
    File.mkdir!(target)
    sentinel = Path.join(target, "keep.txt")
    File.write!(sentinel, "untouched")
    on_exit(fn -> File.rm_rf(target) end)

    assert {:error, "target already exists: " <> _} = Generator.generate(config!(target))
    assert File.read!(sentinel) == "untouched"
  end

  test "blank starter view compiles" do
    suffix = System.unique_integer([:positive])
    app_name = "blank_compile_#{suffix}"
    target = tmp_target(app_name)
    {:ok, config} = Config.new(app_name, target: target, template: :blank)

    view = Template.files(config)["lib/#{app_name}/view.ex"]
    module = Module.concat([Macro.camelize(app_name), "View"])

    assert [{^module, _bytecode}] = Code.compile_string(view)
  end

  test "production error view renders without crash details" do
    suffix = System.unique_integer([:positive])
    app_name = "error_view_compile_#{suffix}"
    target = tmp_target(app_name)
    {:ok, config} = Config.new(app_name, target: target)

    source = Template.files(config)["lib/#{app_name}/error_view.ex"]
    module = Module.concat([Macro.camelize(app_name), "ErrorView"])

    assert [{^module, _bytecode}] = Code.compile_string(source)

    rendered =
      Breeze.Renderer.render_to_string(
        module,
        %{
          view: SecretView,
          kind: :error,
          reason: RuntimeError.exception("sensitive reason"),
          stacktrace: [{SecretView, :sensitive_function, 0, [file: ~c"secret.ex", line: 42]}],
          breeze: %{keybindings: [%{key: "q", label: "Quit"}]}
        },
        theme: Breeze.Theme.builtin(:gruvbox)
      )

    assert rendered =~ "Something went wrong."
    assert rendered =~ "Quit"
    refute rendered =~ "sensitive reason"
    refute rendered =~ "sensitive_function"
    refute rendered =~ "secret.ex"
  end

  test "warns but keeps the generated project when Git is unavailable" do
    target = tmp_target("git_warning")
    on_exit(fn -> File.rm_rf(target) end)

    assert {:ok, result} = Generator.generate(config!(target, init_git: true), git: nil)
    assert [warning] = result.warnings
    assert warning =~ "git executable was not found"
    assert File.exists?(Path.join(target, "mix.exs"))
  end

  test "warns but keeps the generated project when dependency fetching is unavailable" do
    target = tmp_target("deps_warning")
    on_exit(fn -> File.rm_rf(target) end)

    assert {:ok, result} = Generator.generate(config!(target, deps_get: true), mix: nil)
    assert [warning] = result.warnings
    assert warning =~ "mix executable was not found"
    assert File.exists?(Path.join(target, "mix.exs"))
  end

  for template <- Config.templates() do
    @no_theme_cycle_template template

    test "can omit the generated F3 theme binding from the #{@no_theme_cycle_template} starter" do
      target = tmp_target("#{@no_theme_cycle_template}_no_theme_cycle")
      on_exit(fn -> File.rm_rf(target) end)

      assert {:ok, _result} =
               Generator.generate(
                 config!(target,
                   template: @no_theme_cycle_template,
                   theme_cycle: false,
                   storybook: false
                 )
               )

      server_options_path = "lib/sample_app/application.ex"

      server_options = File.read!(Path.join(target, server_options_path))
      readme = File.read!(Path.join(target, "README.md"))

      refute server_options =~ ~s({"F3", "Cycle theme")
      refute server_options =~ "def cycle_theme(event, term)"
      assert server_options =~ ~s({"q", "Quit")
      refute server_options =~ "F10"
      assert {:ok, _ast} = Code.string_to_quoted(server_options)

      assert IO.iodata_to_binary(Code.format_string!(server_options)) <> "\n" ==
               server_options

      refute readme =~ "Press `F3`"
    end
  end

  test "can disable development live reloading" do
    target = tmp_target("no_live_reload")
    on_exit(fn -> File.rm_rf(target) end)

    assert {:ok, _result} = Generator.generate(config!(target, live_reload: false))

    mix_file = File.read!(Path.join(target, "mix.exs"))
    dev_config = File.read!(Path.join(target, "config/dev.exs"))

    refute mix_file =~ ":file_system"
    assert dev_config =~ "reload: false"
  end

  test "can omit Storybook from an example starter" do
    target = tmp_target("no_storybook")
    on_exit(fn -> File.rm_rf(target) end)

    assert {:ok, result} = Generator.generate(config!(target, storybook: false))

    view = File.read!(Path.join(target, "lib/sample_app/view.ex"))
    readme = File.read!(Path.join(target, "README.md"))
    dev_config = File.read!(Path.join(target, "config/dev.exs"))

    refute "lib/sample_app/components.ex" in result.files
    refute "storybook/metric.story.exs" in result.files
    refute view =~ "SampleApp.Components"
    refute view =~ ".metric"
    assert view =~ "Counter: {@counter}"
    refute readme =~ "mix breeze.storybook"
    refute dev_config =~ "storybook_theme"
  end

  test "generated Storybook renders the generated function component" do
    suffix = System.unique_integer([:positive])
    app_name = "storybook_compile_#{suffix}"
    target = tmp_target(app_name)

    {:ok, config} =
      Config.new(app_name,
        target: target,
        init_git: false
      )

    assert {:ok, _result} = Generator.generate(config)
    on_exit(fn -> File.rm_rf(target) end)

    components_module = Module.concat([Macro.camelize(app_name), "Components"])
    components_file = Path.join(target, "lib/#{app_name}/components.ex")

    assert [{^components_module, _bytecode}] = Code.compile_file(components_file)

    session =
      Breeze.Test.start!(Breeze.Storybook,
        size: {100, 24},
        start_opts: [directory: Path.join(target, "storybook")],
        theme: Breeze.Theme.builtin(:gruvbox)
      )

    on_exit(fn -> Breeze.Test.stop(session) end)

    rendered = Breeze.Test.render!(session)
    assert rendered =~ "Metric"
    assert rendered =~ "Items: 3"
  end

  defp config!(target, opts \\ []) do
    defaults = [
      target: target,
      init_git: false
    ]

    {:ok, config} = Config.new("sample_app", Keyword.merge(defaults, opts))
    config
  end

  defp expected_marker(:blank), do: ~s(class="width-screen height-screen bg")
  defp expected_marker(:counter), do: ~s(<.metric label="Counter" value={@counter}/>)

  defp tmp_target(name) do
    Path.join(System.tmp_dir!(), "breeze_new_#{name}_#{System.unique_integer([:positive])}")
  end
end
