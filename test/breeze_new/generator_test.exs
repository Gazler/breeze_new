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
      view_test = File.read!(Path.join(target, "test/sample_app/view_test.exs"))
      application_file = File.read!(Path.join(target, "lib/sample_app/application.ex"))
      error_view = File.read!(Path.join(target, "lib/sample_app/error_view.ex"))
      dev_config = File.read!(Path.join(target, "config/dev.exs"))
      test_config = File.read!(Path.join(target, "config/test.exs"))
      prod_config = File.read!(Path.join(target, "config/prod.exs"))
      readme = File.read!(Path.join(target, "README.md"))
      formatter = File.read!(Path.join(target, ".formatter.exs"))

      for relative_path <- result.files,
          String.ends_with?(relative_path, [".ex", ".exs"]) do
        refute File.read!(Path.join(target, relative_path)) =~ ~r/@(?:spec|type|typedoc)\b/,
               "expected #{relative_path} not to contain a typespec"
      end

      server_options_file =
        if @template == :ssh do
          File.read!(Path.join(target, "lib/sample_app/server.ex"))
        else
          application_file
        end

      assert mix_file =~ "defmodule SampleApp.MixProject"
      assert [_, elixir_requirement] = Regex.run(~r/elixir: "([^"]+)"/, mix_file)
      assert elixir_requirement =~ "#{elixir_major}.#{elixir_minor}"
      assert Version.match?(System.version(), elixir_requirement)
      assert mix_file =~ ~s({:breeze, "~> 0.5.1"})
      assert mix_file =~ ~s(aliases: [run: "run --no-halt"])
      refute mix_file =~ "path:"
      assert mix_file =~ "extra_applications: [:logger]"
      refute mix_file =~ ":os_mon"
      assert root_config =~ "config :back_breeze"
      assert root_config =~ "render_cache_max_memory_bytes: 256 * 1_024 * 1_024"
      refute root_config =~ "config :os_mon"
      assert readme =~ "## Render cache"
      assert readme =~ "render cache is capped at 256 MB"
      assert readme =~ "mix run"
      refute readme =~ "mix run --no-halt"
      assert view_file =~ "defmodule SampleApp.View"
      assert view_file =~ expected_marker(@template)
      assert view_test =~ "Breeze.Test.render_text!("
      refute view_test =~ "Breeze.Test.render!("
      refute view_test =~ "Breeze.ChildServer"

      if @template == :blank do
        refute view_file =~ ".keybinding_bar"
        refute view_file =~ ".panel"
        refute "lib/sample_app/components.ex" in result.files
        refute "storybook/metric.story.exs" in result.files
        refute readme =~ "mix breeze.storybook"
        refute dev_config =~ "storybook_theme"
      else
        assert view_file =~
                 ~s(class="inline w-full h-1 overflow-hidden bg-panel pl-1 pr-1")

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
      assert server_options_file =~ "&Breeze.View.cycle_theme/2"
      refute server_options_file =~ "def cycle_theme(event, term)"
      assert server_options_file =~ ~s({"q", "Quit")
      assert server_options_file =~ "fn _event, term -> {:stop, term} end"

      if @template == :ssh do
        refute server_options_file =~ "System.stop"
        refute application_file =~ "auto_shutdown"
        refute application_file =~ "significant: true"
      else
        assert server_options_file =~ "System.stop(0)"
        assert application_file =~ "breeze_opts = ["
        assert application_file =~ "{Breeze.Server, breeze_opts}"
        assert application_file =~ "auto_shutdown: :any_significant"
        assert application_file =~ "significant: true"
        assert application_file =~ "Shut down the application when the Breeze view exits."

        assert application_file =~
                 "https://www.erlang.org/doc/system/sup_princ.html#all_significant"
      end

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

      if @template == :ssh do
        runtime_config = File.read!(Path.join(target, "config/runtime.exs"))
        ssh_session = File.read!(Path.join(target, "lib/sample_app/ssh_session.ex"))
        local_task = File.read!(Path.join(target, "lib/mix/tasks/sample_app.local.ex"))

        assert "config/runtime.exs" in result.files
        assert "lib/sample_app/server.ex" in result.files
        assert "lib/sample_app/ssh_session.ex" in result.files
        assert "lib/mix/tasks/sample_app.local.ex" in result.files
        assert "priv/ssh/.gitkeep" in result.files
        assert mix_file =~ ~s({:termite_ssh, "~> 0.1.0"})
        assert application_file =~ "{Termite.SSH, options}"
        assert application_file =~ "entrypoint: {SampleApp.SSHSession, []}"
        assert application_file =~ "Logger.debug(\"SSH listener ready. Connect with:"
        assert application_file =~ "PreferredAuthentications=none"
        assert application_file =~ ~S|" -p " <> to_string(port)|
        assert application_file =~ ~S|defp ssh_user(:none), do: "demo"|
        assert ssh_session =~ "Termite.SSH.terminal(session)"
        assert ssh_session =~ "send(server, message)"
        assert ssh_session =~ "Termite.SSH.disconnect(session)"
        assert dev_config =~ "auth: :none"
        assert dev_config =~ "allow_insecure_auth: true"
        assert test_config =~ "auth: :none"
        assert test_config =~ "start_server: false"
        assert runtime_config =~ "SAMPLE_APP_SSH_AUTHORIZED_KEYS_DIR"
        assert runtime_config =~ "auth: {:public_key, [{username, authorized_keys_dir}]}"
        refute runtime_config =~ "allow_insecure_auth"
        assert local_task =~ "defmodule Mix.Tasks.SampleApp.Local"
        assert local_task =~ "Application.put_env(:sample_app, :start_server, false)"
        assert local_task =~ ~s|Mix.Task.run("app.start")|
        refute local_task =~ "Application.ensure_all_started"
        assert local_task =~ "SampleApp.Server.run("
        assert readme =~ "mix sample_app.local"
        assert readme =~ "mix termite.ssh.gen_host_key"
        assert readme =~ "SAMPLE_APP_SSH_SYSTEM_DIR"
        assert {:ok, _ast} = Code.string_to_quoted(ssh_session)
        assert {:ok, _ast} = Code.string_to_quoted(local_task)
        assert {:ok, _ast} = Code.string_to_quoted(runtime_config)

        assert IO.iodata_to_binary(Code.format_string!(ssh_session)) <> "\n" == ssh_session
        assert IO.iodata_to_binary(Code.format_string!(local_task)) <> "\n" == local_task
      else
        refute "config/runtime.exs" in result.files
        refute mix_file =~ ":termite_ssh"
      end

      if @template == :kitchen_sink do
        assert "lib/sample_app/kitchen_sink.ex" in result.files
        assert readme =~ "## Browse the component gallery"
        assert readme =~ "every built-in component in `Breeze.Blocks`"
        assert view_test =~ "Breeze.Test.focus("
        assert view_test =~ "Breeze.Test.click("
      end

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

      if @dynamic_cache_template == :ssh do
        local_task = File.read!(Path.join(target, "lib/mix/tasks/sample_app.local.ex"))

        assert local_task =~ ~s|Mix.Task.run("app.start")|
        refute local_task =~ "Application.ensure_all_started"
      end

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

    assert mix_file =~ ~s({:breeze, "~> 0.5.1"})
    refute mix_file =~ "path:"
  end

  test "standalone Quit waits for Breeze cleanup before stopping the runtime" do
    target = tmp_target("quit_lifecycle")

    {:ok, config} =
      Config.new("quit_lifecycle",
        target: target,
        template: :blank,
        theme: :system,
        theme_cycle: false,
        storybook: false,
        init_git: false
      )

    application_source =
      config
      |> Template.files()
      |> Map.fetch!("lib/quit_lifecycle/application.ex")
      |> String.replace("Breeze.Server", "QuitLifecycle.Server")
      |> Base.encode64()

    script = """
    defmodule QuitLifecycle.Server do
      use GenServer

      def start_link(options), do: GenServer.start_link(__MODULE__, options, name: __MODULE__)

      @impl true
      def init(options) do
        Process.flag(:trap_exit, true)
        {:ok, options}
      end

      @impl true
      def handle_call(:quit, _from, options) do
        {"q", "Quit", handler} = List.keyfind(options[:global_keybindings], "q", 0)
        result = handler.(nil, :term)
        {:stop, :normal, result, options}
      end

      @impl true
      def terminate(reason, _state) do
        IO.puts("server terminated: \#{inspect(reason)}")
      end
    end

    #{inspect(application_source)}
    |> Base.decode64!()
    |> Code.compile_string()

    :ok =
      :application.load(
        {:application, :quit_lifecycle,
         [
           {:description, ~c"quit lifecycle test"},
           {:vsn, ~c"0.1.0"},
           {:modules, [QuitLifecycle.Application, QuitLifecycle.Server]},
           {:registered, []},
           {:applications, [:kernel, :stdlib, :elixir]},
           {:mod, {QuitLifecycle.Application, []}}
         ]}
      )

    :ok = Application.start(:quit_lifecycle)
    {:stop, :term} = GenServer.call(QuitLifecycle.Server, :quit)
    Process.sleep(2_000)
    System.halt(99)
    """

    timeout = System.find_executable("timeout")
    elixir = System.find_executable("elixir")

    assert is_binary(timeout)
    assert is_binary(elixir)

    {output, status} =
      System.cmd(timeout, ["5", elixir, "--no-halt", "-e", script], stderr_to_stdout: true)

    assert status == 0, output
    assert output =~ "server terminated: :normal"
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

      if @timeline_template == :ssh do
        local_task = File.read!(Path.join(target, "lib/mix/tasks/sample_app.local.ex"))

        assert mix_file =~ ":termite_ssh"
        assert dev_config =~ "auth: :none"
        assert local_task =~ "Application.put_env(:sample_app, :start_server, false)"
        assert local_task =~ ~s|Mix.Task.run("app.start")|
        refute local_task =~ "Application.ensure_all_started"
        assert {:ok, _ast} = Code.string_to_quoted(local_task)
        assert IO.iodata_to_binary(Code.format_string!(local_task)) <> "\n" == local_task
      end

      assert IO.iodata_to_binary(Code.format_string!(mix_file)) <> "\n" == mix_file
      assert IO.iodata_to_binary(Code.format_string!(dev_config)) <> "\n" == dev_config
    end
  end

  for template <- Config.templates() do
    @theme_cycle_template template

    test "F3 uses Breeze's theme cycle in the #{@theme_cycle_template} starter" do
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

      callback_module =
        if @theme_cycle_template == :ssh do
          Module.concat([module_name, "Server"])
        else
          Module.concat([module_name, "Application"])
        end

      if @theme_cycle_template == :kitchen_sink do
        kitchen_sink_module = Module.concat([module_name, "KitchenSink"])

        assert [{^kitchen_sink_module, _bytecode}] =
                 Code.compile_string(
                   files["lib/#{app_name}/kitchen_sink.ex"],
                   "lib/#{app_name}/kitchen_sink.ex"
                 )
      end

      assert [{^view_module, _bytecode}] =
               Code.compile_string(files["lib/#{app_name}/view.ex"])

      callback_path =
        if @theme_cycle_template == :ssh,
          do: "lib/#{app_name}/server.ex",
          else: "lib/#{app_name}/application.ex"

      assert [{^callback_module, _bytecode}] =
               Code.compile_string(files[callback_path])

      session =
        Breeze.Test.start!(view_module,
          size: {80, 20},
          theme: Breeze.Theme.builtin(:gruvbox),
          global_keybindings: [{"F3", "Cycle theme", &Breeze.View.cycle_theme/2}]
        )

      on_exit(fn -> Breeze.Test.stop(session) end)

      assert get_in(Breeze.Test.metadata(session).assigns, [:breeze, :theme, :name]) ==
               "gruvbox-dark"

      Breeze.Test.input(session, "F3")

      assert get_in(Breeze.Test.metadata(session).assigns, [:breeze, :theme, :name]) == :system16

      Breeze.Test.input(session, "F3")

      assert get_in(Breeze.Test.metadata(session).assigns, [:breeze, :theme, :name]) == :system
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

  test "list starter compiles with its generated component" do
    suffix = System.unique_integer([:positive])
    app_name = "list_compile_#{suffix}"
    target = tmp_target(app_name)
    {:ok, config} = Config.new(app_name, target: target, template: :list)
    files = Template.files(config)
    module_name = Macro.camelize(app_name)
    components_module = Module.concat([module_name, "Components"])
    view_module = Module.concat([module_name, "View"])

    assert [{^components_module, _bytecode}] =
             Code.compile_string(
               files["lib/#{app_name}/components.ex"],
               "lib/#{app_name}/components.ex"
             )

    assert [{^view_module, _bytecode}] =
             Code.compile_string(files["lib/#{app_name}/view.ex"], "lib/#{app_name}/view.ex")

    session = Breeze.Test.start!(view_module, size: {80, 20})
    on_exit(fn -> Breeze.Test.stop(session) end)

    assert Breeze.Test.render!(session) =~ "Build the interface"
    Breeze.Test.input(session, "ArrowDown")
    assert %{assigns: %{selected: "second"}} = Breeze.Test.metadata(session)
  end

  test "Kitchen Sink starter compiles and renders every component section" do
    suffix = System.unique_integer([:positive])
    app_name = "kitchen_sink_compile_#{suffix}"
    target = tmp_target(app_name)
    {:ok, config} = Config.new(app_name, target: target, template: :kitchen_sink)
    files = Template.files(config)
    module_name = Macro.camelize(app_name)
    components_module = Module.concat([module_name, "Components"])
    kitchen_sink_module = Module.concat([module_name, "KitchenSink"])
    view_module = Module.concat([module_name, "View"])

    assert [{^components_module, _bytecode}] =
             Code.compile_string(
               files["lib/#{app_name}/components.ex"],
               "lib/#{app_name}/components.ex"
             )

    kitchen_sink_source = files["lib/#{app_name}/kitchen_sink.ex"]
    view_source = files["lib/#{app_name}/view.ex"]

    assert kitchen_sink_source =~
             ~s(class="p-1 pr-2 w-full bg-panel")

    assert kitchen_sink_source =~
             ~s(class="w-full h-6 bg-panel focus:scrollbar-primary")

    for section <- ~w(controls collections content feedback) do
      assert kitchen_sink_source =~ ~s(<:tab value="#{section}")
      assert kitchen_sink_source =~ ~s(<.#{section}_tab)
      assert kitchen_sink_source =~ "defp #{section}_tab(assigns)"
      assert kitchen_sink_source =~ ~s(id="gallery-tabs-panel-#{section}")
    end

    refute kitchen_sink_source =~ ~s(panel={false})
    refute kitchen_sink_source =~ ~s(:if={@section ==)

    refute kitchen_sink_source =~
             ~r/^\s+@(sections|component_names|nodes|cities|markdown|log_lines)\b/m

    assert [{^kitchen_sink_module, _bytecode}] =
             Code.compile_string(kitchen_sink_source, "lib/#{app_name}/kitchen_sink.ex")

    assert [{^view_module, _bytecode}] =
             Code.compile_string(view_source, "lib/#{app_name}/view.ex")

    for component <-
          ~w(button checkbox dropdown input list markdown panel scroll table tabs textarea tree) do
      assert kitchen_sink_source =~ "<.#{component}"
    end

    for component <- ~w(flash_group keybinding_bar modal) do
      assert view_source =~ "<.#{component}"
    end

    assert Enum.sort(kitchen_sink_module.component_names()) ==
             Enum.sort(~w(
               button checkbox dropdown flash_group input keybinding_bar list markdown modal
               panel scroll table tabs textarea tree
             ))

    session = Breeze.Test.start!(view_module, size: {100, 30})
    on_exit(fn -> Breeze.Test.stop(session) end)

    assert Breeze.Test.render!(session) =~ "Actions triggered: 0"

    Breeze.Test.event(session, "section_changed", %{value: "collections"})
    assert Breeze.Test.render!(session) =~ "Table"

    Breeze.Test.event(session, "section_changed", %{value: "content"})
    assert Breeze.Test.render!(session) =~ "Markdown"

    short = Breeze.Test.start!(view_module, size: {204, 20})
    on_exit(fn -> Breeze.Test.stop(short) end)

    controls_before_scroll = Breeze.Test.render!(short)
    assert controls_before_scroll =~ "Button"

    Breeze.ChildServer.set_focus(short.pid, "gallery-tabs-panel-controls")
    Breeze.Test.input(short, "PageDown")
    controls_after_scroll = Breeze.Test.render!(short)

    refute controls_after_scroll == controls_before_scroll
    refute controls_after_scroll =~ "Button"
    assert controls_after_scroll =~ "Textarea"

    Breeze.Test.event(short, "section_changed", %{value: "content"})
    short_before_scroll = Breeze.Test.render!(short)
    assert short_before_scroll =~ "Panel"

    Breeze.ChildServer.set_focus(short.pid, "gallery-tabs-panel-content")
    Breeze.Test.input(short, "PageDown")
    short_after_scroll = Breeze.Test.render!(short)

    refute short_after_scroll == short_before_scroll
    refute short_after_scroll =~ "Panel"
    assert short_after_scroll =~ "Markdown"

    targets = Breeze.ChildServer.layout_snapshot(session.pid).mouse_targets
    outer_target = targets["gallery-tabs-panel-content"]
    panel_target = targets["demo-panel"]

    assert outer_target.right - panel_target.right == 2

    Breeze.ChildServer.set_focus(session.pid, "demo-scroll")
    Breeze.Test.input(session, "PageDown")

    assert {Breeze.Implicit.Scroll, %{offset_y: inner_offset}} =
             Breeze.Test.metadata(session).implicit_state["demo-scroll"]

    assert inner_offset > 0

    Breeze.ChildServer.set_focus(session.pid, "demo-markdown")
    Breeze.Test.input(session, "PageDown")

    assert {Breeze.Implicit.Scroll, %{offset_y: markdown_offset}} =
             Breeze.Test.metadata(session).implicit_state["demo-markdown"]

    assert markdown_offset > 0

    wide = Breeze.Test.start!(view_module, size: {204, 29})
    on_exit(fn -> Breeze.Test.stop(wide) end)

    Breeze.Test.event(wide, "section_changed", %{value: "content"})
    Breeze.Test.render!(wide)

    wide_outer = :sys.get_state(wide.pid).elements["gallery-tabs-panel-content"]

    assert wide_outer.content_height <= wide_outer.viewport_height

    Breeze.Test.event(session, "section_changed", %{value: "feedback"})
    assert Breeze.Test.render!(session) =~ "Open modal"

    compact = Breeze.Test.start!(view_module, size: {40, 18})
    on_exit(fn -> Breeze.Test.stop(compact) end)

    Enum.each(~w(controls collections content feedback), fn section ->
      Breeze.Test.event(compact, "section_changed", %{value: section})

      rows =
        compact
        |> Breeze.Test.render!()
        |> BackBreeze.Utils.strip_escape_chars()
        |> String.split("\n")

      assert length(rows) == 18
      assert Enum.all?(rows, &(String.length(&1) == 40))
    end)

    Breeze.Test.event(compact, "section_changed", %{value: "content"})
    Breeze.Test.render!(compact)
    Breeze.ChildServer.set_focus(compact.pid, "gallery-tabs-panel-content")
    Breeze.Test.input(compact, "PageDown")

    assert {Breeze.Implicit.Scroll, %{offset_y: compact_outer_offset}} =
             Breeze.Test.metadata(compact).implicit_state["gallery-tabs-panel-content"]

    assert compact_outer_offset > 0
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

      server_options_path =
        if @no_theme_cycle_template == :ssh,
          do: "lib/sample_app/server.ex",
          else: "lib/sample_app/application.ex"

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

  defp expected_marker(:blank), do: ~s(class="w-screen h-screen bg")
  defp expected_marker(:counter), do: ~s(<.metric label="Counter" value={@counter}/>)
  defp expected_marker(:list), do: ~s(id="tasks")
  defp expected_marker(:kitchen_sink), do: ~s(id="kitchen-sink")
  defp expected_marker(:ssh), do: "Connected as {@username}"

  defp tmp_target(name) do
    Path.join(System.tmp_dir!(), "breeze_new_#{name}_#{System.unique_integer([:positive])}")
  end
end
