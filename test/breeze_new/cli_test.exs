defmodule BreezeNew.CLITest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias BreezeNew.CLI

  test "parses non-interactive project options" do
    assert {:ok, config, false} =
             CLI.parse([
               "--no-tui",
               "--template",
               "list",
               "--theme",
               "system",
               "--no-theme-cycle",
               "--cache-size",
               "512",
               "--deps-get",
               "--no-mouse",
               "--no-inspector",
               "--no-timeline",
               "--no-live-reload",
               "--no-storybook",
               "--no-git",
               "sample_app"
             ])

    assert config.template == :list
    assert config.theme == :system
    refute config.theme_cycle
    assert config.cache_size == 512
    assert config.deps_get
    refute config.mouse
    refute config.inspector
    refute config.timeline
    refute config.live_reload
    refute config.storybook
    refute config.init_git
  end

  test "returns help and version without a project name" do
    assert {:help, usage} = CLI.parse(["--help"])
    assert usage =~ "Usage: breeze_new [PROJECT]"
    assert usage =~ "--template blank|counter|list|kitchen_sink|ssh"
    assert usage =~ "commander"
    assert usage =~ "catppuccin"
    assert usage =~ "solarized_light"
    assert usage =~ "solarized_dark"
    assert usage =~ "--cache-size MB|dynamic"
    assert usage =~ "default: 256"
    assert usage =~ "--[no-]live-reload"
    assert usage =~ "--[no-]timeline"
    assert usage =~ "--[no-]storybook"
    assert {:version, version} = CLI.parse(["--version"])
    assert version =~ ~r/^\d+\.\d+\.\d+$/
  end

  test "accepts dynamic cache sizing and rejects invalid sizes" do
    assert {:ok, %{cache_size: :dynamic}, false} =
             CLI.parse(["--no-tui", "--cache-size", "dynamic", "sample_app"])

    assert {:error, message} =
             CLI.parse(["--no-tui", "--cache-size", "0", "sample_app"])

    assert message =~ ~s(cache size must be a positive integer in MB or "dynamic")
  end

  test "does not enable Storybook for the blank starter" do
    assert {:ok, config, false} =
             CLI.parse(["--no-tui", "--template", "blank", "--storybook", "sample_app"])

    refute config.storybook
  end

  test "accepts the SSH starter" do
    assert {:ok, config, false} =
             CLI.parse(["--no-tui", "--template", "ssh", "sample_app"])

    assert config.template == :ssh
  end

  test "accepts the Kitchen Sink starter" do
    assert {:ok, config, false} =
             CLI.parse(["--no-tui", "--template", "kitchen_sink", "sample_app"])

    assert config.template == :kitchen_sink
    assert config.storybook
  end

  test "accepts Timeline for any starter" do
    assert {:ok, config, false} =
             CLI.parse(["--no-tui", "--template", "list", "--timeline", "sample_app"])

    assert config.template == :list
    assert config.timeline
    assert config.breeze_dep == {:hex, "~> 0.5.0"}

    assert {:error, message} =
             CLI.parse([
               "--no-tui",
               "--template",
               "list",
               "--timeline",
               "--no-inspector",
               "sample_app"
             ])

    assert message =~ "Inspector must be enabled when Timeline is enabled"
  end

  test "prints SSH and local run instructions after generating an SSH starter" do
    app_name = "ssh_after_#{System.unique_integer([:positive])}"
    target = Path.join(System.tmp_dir!(), app_name)
    on_exit(fn -> File.rm_rf(target) end)

    output =
      capture_io(fn ->
        CLI.main(["--no-tui", "--template", "ssh", "--no-git", target])
      end)

    assert output =~ "mix termite.ssh.gen_host_key"
    assert output =~ "mix run --no-halt"
    assert output =~ "Or run the view locally without SSH:"
    assert output =~ "mix #{app_name}.local"
  end

  test "prints Timeline inspector instructions when Timeline is enabled" do
    app_name = "timeline_after_#{System.unique_integer([:positive])}"
    target = Path.join(System.tmp_dir!(), app_name)
    on_exit(fn -> File.rm_rf(target) end)

    output =
      capture_io(fn ->
        CLI.main([
          "--no-tui",
          "--template",
          "list",
          "--timeline",
          "--no-git",
          target
        ])
      end)

    assert output =~ "mix run --no-halt"
    assert output =~ "Inspect and rewind it from another terminal:"
    assert output =~ "mix breeze.inspector"
  end

  test "reports malformed invocations" do
    assert {:error, "expected a project name when --no-tui is used"} = CLI.parse(["--no-tui"])
    assert {:error, "expected at most one project name"} = CLI.parse(["one", "two"])
    assert {:error, message} = CLI.parse(["--wat", "sample"])
    assert message =~ "unknown or invalid option"
  end

  test "starts the wizard without a project name" do
    assert {:ok, config, true} = CLI.parse([])
    assert config.app_name == ""
    assert config.module_name == ""
    assert config.target == File.cwd!()
  end

  test "uses CRLF after the TUI returns" do
    assert CLI.format_output("Created project\n\nNext steps:", true) ==
             "Created project\r\n\r\nNext steps:\r\n"

    assert CLI.format_output("Created project", false) == "Created project\n"
  end
end
