defmodule BreezeNew.PreviewTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias BreezeNew.Preview

  test "lists every preview starter" do
    assert Preview.templates() == [:blank, :counter]
  end

  for template <- [:blank, :counter] do
    @template template

    test "compiles and renders the #{@template} starter without writing a project" do
      app_name = preview_app_name(@template)
      target = Path.join(System.tmp_dir!(), app_name)

      refute File.exists?(target)

      assert {:ok, preview} =
               Preview.prepare(@template,
                 app_name: app_name,
                 target: target
               )

      on_exit(fn -> Preview.unload(preview) end)

      assert preview.config.template == @template
      assert function_exported?(preview.view, :render, 1)

      session = Breeze.Test.start!(preview.view, size: {80, 24})
      on_exit(fn -> Breeze.Test.stop(session) end)

      assert is_binary(Breeze.Test.render!(session))
      refute File.exists?(target)
    end
  end

  test "rejects unknown starters" do
    assert {:error, message} = Preview.prepare("missing")
    assert message =~ "unknown preview starter"
    assert message =~ "blank, counter"
  end

  test "runs with local development options and unloads its modules" do
    app_name = preview_app_name(:runner)
    parent = self()

    runner = fn options ->
      send(parent, {:preview_options, options, Code.ensure_loaded?(options[:view])})
      :ok
    end

    assert :ok = Preview.run(:counter, app_name: app_name, runner: runner)

    assert_receive {:preview_options, options, true}
    assert options[:view] == Module.concat([Macro.camelize(app_name), "View"])
    assert %Breeze.Theme{} = options[:theme]
    assert options[:mouse]
    assert options[:inspector] == [remote: false]
    assert options[:logger] == :replace
    refute options[:reload]

    assert [{"F3", "Cycle theme", cycle}, {"q", "Quit", quit}] =
             options[:global_keybindings]

    assert is_function(cycle, 2)
    assert is_function(quit, 2)
    refute Code.ensure_loaded?(options[:view])
  end

  test "the Mix task reports unsupported invocations" do
    invalid_output =
      capture_io(fn ->
        assert_raise Mix.Error, ~r/unknown preview starter/, fn ->
          Mix.Tasks.BreezeNew.Preview.run(["missing"])
        end
      end)

    assert invalid_output =~ "Previewing missing"

    assert_raise Mix.Error, ~r/expected one starter/, fn ->
      Mix.Tasks.BreezeNew.Preview.run([])
    end
  end

  defp preview_app_name(template) do
    "preview_#{template}_#{System.unique_integer([:positive])}"
  end
end
