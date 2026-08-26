defmodule BreezeNew.ConfigTest do
  use ExUnit.Case, async: true

  alias BreezeNew.Config

  test "builds names and accepts string choices" do
    target = tmp_target("config")

    assert {:ok, config} =
             Config.new("nested/my_app", target: target, template: "list", theme: "commander")

    assert config.app_name == "my_app"
    assert config.module_name == "MyApp"
    assert config.target == Path.expand(target)
    assert config.template == :list
    assert config.theme == :commander
    assert config.cache_size == 256
    assert config.live_reload
    assert config.storybook
    refute config.timeline
    assert config.breeze_dep == {:hex, "~> 0.5.0"}
    assert config.breeze_timeline_dep == {:hex, "~> 0.1.0"}
  end

  test "accepts a fixed render cache size or dynamic allocation" do
    assert {:ok, %{cache_size: 512}} = Config.new("valid", cache_size: 512)
    assert {:ok, %{cache_size: 768}} = Config.new("valid", cache_size: " 768 ")
    assert {:ok, %{cache_size: :dynamic}} = Config.new("valid", cache_size: :dynamic)
    assert {:ok, %{cache_size: :dynamic}} = Config.new("valid", cache_size: "DYNAMIC")

    for invalid <- [0, -1, "0", "12 MB", :auto, nil] do
      assert {:error, message} = Config.new("valid", cache_size: invalid)
      assert message == ~s(cache size must be a positive integer in MB or "dynamic")
    end
  end

  test "rejects invalid project names and choices" do
    assert {:error, message} = Config.new("My-App")
    assert message =~ "project name must start"

    assert {:error, "unknown template :unknown" <> _} = Config.new("valid", template: :unknown)
    assert {:error, "unknown theme \"unknown\"" <> _} = Config.new("valid", theme: "unknown")
  end

  test "only exposes themes supported by Breeze" do
    assert Config.themes() == [
             :dracula,
             :commander,
             :gruvbox,
             :catppuccin,
             :nord,
             :solarized_light,
             :solarized_dark,
             :system
           ]

    Enum.each(Config.themes(), fn
      :system ->
        assert %Breeze.Theme{} = theme = Breeze.Theme.new(:system)
        assert Breeze.Theme.requested_system?(theme)

      theme ->
        assert %Breeze.Theme{} = Breeze.Theme.builtin(theme)
    end)
  end

  test "exposes the blank starter before the example starters" do
    assert Config.templates() == [:blank, :counter, :list, :kitchen_sink, :ssh]

    assert {:ok, %{template: :blank, storybook: false}} =
             Config.new("valid", template: "blank")

    assert {:ok, %{storybook: false}} =
             Config.new("valid", template: :blank, storybook: true)

    assert {:ok, %{template: :ssh, storybook: true}} =
             Config.new("valid", template: "ssh")

    assert {:ok, %{template: :kitchen_sink, storybook: true}} =
             Config.new("valid", template: "kitchen_sink")
  end

  test "enables Timeline independently of the starter without changing its Breeze dependency" do
    assert {:ok,
            %{
              template: :list,
              timeline: true,
              inspector: true,
              breeze_dep: {:hex, "~> 0.5.0"}
            }} = Config.new("valid", template: "list", timeline: true)

    assert {:error, message} =
             Config.new("valid", template: "list", timeline: true, inspector: false)

    assert message =~ "Inspector must be enabled when Timeline is enabled"

    {:ok, config} = Config.new("valid", template: "ssh")
    assert %{timeline: true, breeze_dep: {:hex, "~> 0.5.0"}} = Config.put_timeline(config, true)

    pinned_config = %{config | breeze_dep: {:hex, "== 0.5.0"}}

    assert %{timeline: true, breeze_dep: {:hex, "== 0.5.0"}} =
             Config.put_timeline(pinned_config, true)
  end

  test "validates the target and Git commit message" do
    target = tmp_target("validation")
    File.mkdir!(target)
    on_exit(fn -> File.rm_rf(target) end)

    {:ok, existing} = Config.new("valid", target: target)
    assert {:error, "target already exists: " <> _} = Config.validate(existing)

    missing_parent = Path.join([target, "missing", "project"])
    {:ok, missing} = Config.new("valid", target: missing_parent)
    assert {:error, "parent directory does not exist: " <> _} = Config.validate(missing)

    blank_target = tmp_target("blank_commit")
    {:ok, blank} = Config.new("valid", target: blank_target, commit_message: "  ")
    assert {:error, message} = Config.validate(blank)
    assert message =~ "commit message cannot be empty"

    assert :ok = Config.validate(%{blank | init_git: false})
  end

  test "validates values supplied through the public struct" do
    target = tmp_target("struct")
    {:ok, config} = Config.new("valid", target: target)

    assert {:error, message} = Config.validate(%{config | module_name: "Wrong"})
    assert message =~ "module name must match"

    assert {:error, message} = Config.validate(%{config | mouse: :yes})
    assert message =~ "expected boolean value for mouse"

    assert {:error, message} = Config.validate(%{config | live_reload: :yes})
    assert message =~ "expected boolean value for live_reload"

    assert {:error, message} = Config.validate(%{config | storybook: :yes})
    assert message =~ "expected boolean value for storybook"

    assert {:error, message} = Config.validate(%{config | cache_size: 0})
    assert message =~ "cache size must be a positive integer"

    assert {:error, message} = Config.validate(%{config | cache_size: "512"})
    assert message =~ "cache size must be a positive integer"

    assert {:error, message} = Config.validate(%{config | timeline: :yes})
    assert message =~ "expected boolean value for timeline"

    assert {:error, message} =
             Config.validate(%{config | timeline: true, inspector: false})

    assert message =~ "Inspector must be enabled when Timeline is enabled"

    assert {:error, message} = Config.validate(%{config | template: :blank, storybook: true})
    assert message =~ "Storybook is not available for the blank starter"

    assert {:error, message} = Config.validate(%{config | breeze_dep: {:hex, "not a req"}})
    assert message =~ "invalid Breeze version requirement"

    assert {:error, message} = Config.validate(%{config | breeze_dep: {:path, "deps/breeze"}})
    assert message == "Breeze dependency must be {:hex, requirement}"

    assert {:error, message} =
             Config.validate(%{config | breeze_timeline_dep: {:hex, "not a req"}})

    assert message =~ "invalid Breeze Timeline version requirement"

    assert {:error, message} =
             Config.validate(%{config | breeze_timeline_dep: {:path, "deps/breeze_timeline"}})

    assert message == "Breeze Timeline dependency must be {:hex, requirement}"

    assert {:error, message} =
             Config.validate(%{config | termite_ssh_dep: {:hex, "not a req"}})

    assert message =~ "invalid Termite SSH version requirement"

    assert {:error, message} =
             Config.validate(%{config | termite_ssh_dep: {:path, "deps/termite_ssh"}})

    assert message == "Termite SSH dependency must be {:hex, requirement}"
  end

  defp tmp_target(name) do
    Path.join(System.tmp_dir!(), "breeze_new_#{name}_#{System.unique_integer([:positive])}")
  end
end
