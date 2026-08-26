defmodule BreezeNew.WizardTest do
  use ExUnit.Case, async: true

  alias BreezeNew.{Config, Wizard}

  test "renders the complete form and updates its configuration" do
    session = start_wizard()
    on_exit(fn -> Breeze.Test.stop(session) end)

    rendered = Breeze.Test.render!(session)
    target = Breeze.Test.metadata(session).assigns.config.target

    assert rendered =~ "Create a Breeze application"
    assert rendered =~ "Project name"
    assert rendered =~ target
    refute rendered =~ "Target"
    assert rendered =~ "Create project"
    assert rendered =~ "Initial commit"
    assert rendered =~ "An interactive counter with keyboard controls."
    assert rendered =~ "Use F3 to cycle themes"
    assert rendered =~ "Live reload"
    assert rendered =~ "Timeline"
    assert rendered =~ "Storybook"
    assert rendered =~ "Run mix deps.get"
    assert rendered =~ "Cache"
    assert rendered =~ "Limit in MB"
    assert rendered =~ "Dynamic with os_mon"
    assert rendered =~ "256"
    assert rendered =~ "Next field"
    assert rendered =~ "Toggle"
    assert rendered =~ "Create"
    assert rendered =~ "Cancel"
    refute rendered =~ "Esc"

    refute Enum.any?(
             Breeze.Test.metadata(session).active_keybindings,
             &(&1.key in ["Esc", "Escape"])
           )

    Breeze.Test.event(session, "name_changed", %{value: "renamed_app"})
    Breeze.Test.event(session, "template_changed", %{value: "blank"})
    Breeze.Test.event(session, "theme_changed", %{value: "system"})
    Breeze.Test.event(session, "theme_cycle_changed", %{value: false})
    Breeze.Test.event(session, "deps_get_changed", %{value: true})
    Breeze.Test.event(session, "mouse_changed", %{value: false})
    Breeze.Test.event(session, "timeline_changed", %{value: true})
    Breeze.Test.event(session, "live_reload_changed", %{value: false})
    Breeze.Test.event(session, "storybook_changed", %{value: false})

    assert %{assigns: %{config: config}} = Breeze.Test.metadata(session)
    assert config.app_name == "renamed_app"
    assert config.module_name == "RenamedApp"
    assert Path.basename(config.target) == "renamed_app"
    assert config.template == :blank
    assert config.theme == :system
    refute config.theme_cycle
    assert config.cache_size == 256
    assert config.deps_get
    refute config.mouse
    assert config.timeline
    assert config.breeze_dep == {:hex, "~> 0.5.0"}
    refute config.live_reload
    refute config.storybook
    assert get_in(Breeze.Test.metadata(session), [:assigns, :breeze, :theme, :name]) == :system
  end

  test "keeps theme cycling with Theme and groups the Git settings" do
    session = start_wizard()
    on_exit(fn -> Breeze.Test.stop(session) end)

    rows = session |> Breeze.Test.render!() |> strip_ansi() |> String.split("\n")
    panel_top_row = Enum.find_index(rows, &String.contains?(&1, "Create a Breeze application"))
    project_row = Enum.find_index(rows, &String.contains?(&1, "Project name"))
    theme_row = Enum.find_index(rows, &String.contains?(&1, "Gruvbox"))
    cycle_row = Enum.find_index(rows, &String.contains?(&1, "Use F3 to cycle themes"))

    assert project_row == panel_top_row + 2
    assert cycle_row == theme_row + 1
    assert rows |> Enum.at(cycle_row + 1) |> String.trim() =~ ~r/^│\s+│$/

    options_row = Enum.find_index(rows, &String.contains?(&1, "Options"))
    mouse_row = Enum.find_index(rows, &String.contains?(&1, "Mouse"))
    storybook_row = Enum.find_index(rows, &String.contains?(&1, "Storybook"))
    cache_row = Enum.find_index(rows, &String.contains?(&1, "Dynamic with os_mon"))
    cache_input_row = Enum.find_index(rows, &String.contains?(&1, "Limit in MB"))
    git_row = Enum.find_index(rows, &String.contains?(&1, "Git repository"))
    commit_row = Enum.find_index(rows, &String.contains?(&1, "Initial commit"))

    assert options_row == mouse_row
    assert cache_row == storybook_row + 2
    assert cache_input_row == cache_row + 1
    assert git_row == cache_input_row + 2
    assert commit_row == git_row + 1
    assert Enum.at(rows, git_row) =~ ~r/│\s*Git\s+\[x\] Git repository/
  end

  test "accepts fixed and dynamic cache sizing and validates the input" do
    session = start_wizard()
    on_exit(fn -> Breeze.Test.stop(session) end)

    fixed_rendered = Breeze.Test.render!(session)

    Breeze.Test.event(session, "cache_size_changed", %{value: "512"})
    assert Breeze.Test.metadata(session).assigns.config.cache_size == 512

    Breeze.Test.event(session, "dynamic_cache_changed", %{value: true})
    assert Breeze.Test.metadata(session).assigns.config.cache_size == :dynamic
    assert Breeze.Test.metadata(session).assigns.cache_size_input == "512"

    dynamic_rendered = Breeze.Test.render!(session)

    assert {Breeze.Implicit.Checkbox, %{checked: true}} =
             Breeze.Test.metadata(session).implicit_state["dynamic-cache"]

    refute Map.has_key?(Breeze.Test.metadata(session).implicit_state, "cache-size")
    refute dynamic_rendered =~ "Limit in MB"
    assert panel_bottom_row(dynamic_rendered) == panel_bottom_row(fixed_rendered)

    Breeze.Test.event(session, "dynamic_cache_changed", %{value: false})
    assert Breeze.Test.metadata(session).assigns.config.cache_size == 512
    assert Breeze.Test.render!(session) =~ "Limit in MB"

    Breeze.Test.event(session, "cache_size_changed", %{value: "0"})
    assert Breeze.Test.metadata(session).assigns.cache_size_input == "0"
    assert Breeze.Test.metadata(session).assigns.config.cache_size == 512

    Breeze.Test.event(session, "create", %{})

    assert Process.alive?(session.pid)
    assert Breeze.Test.render!(session) =~ "cache size must be a positive integer"
    refute_received {:breeze_new, _result}
  end

  test "uses the default fixed size when disabling an initially dynamic cache" do
    target =
      Path.join(System.tmp_dir!(), "breeze_new_dynamic_#{System.unique_integer([:positive])}")

    {:ok, config} = Config.new("sample_app", target: target, cache_size: :dynamic)

    session =
      Breeze.Test.start!(Wizard,
        size: {80, 24},
        start_opts: [config: config, caller: self()],
        theme: Breeze.Theme.builtin(:gruvbox)
      )

    on_exit(fn -> Breeze.Test.stop(session) end)

    assert Breeze.Test.metadata(session).assigns.cache_size_input == "256"
    assert session |> Breeze.Test.render!() |> strip_ansi() =~ "[x] Dynamic with os_mon"
    refute Breeze.Test.render!(session) =~ "Limit in MB"

    Breeze.Test.event(session, "dynamic_cache_changed", %{value: false})
    assert Breeze.Test.metadata(session).assigns.config.cache_size == 256
  end

  test "updates the starter description" do
    session = start_wizard()
    on_exit(fn -> Breeze.Test.stop(session) end)
    initial_height = session |> Breeze.Test.render!() |> strip_ansi() |> panel_height()

    Breeze.Test.event(session, "template_changed", %{value: "blank"})
    rendered = Breeze.Test.render!(session)
    assert rendered =~ "A minimal Breeze view with no example interface."
    assert rendered |> strip_ansi() |> panel_height() == initial_height
    assert strip_ansi(rendered) =~ "⟦ ⟧ Storybook"
    refute Breeze.Test.metadata(session).assigns.config.storybook

    assert {Breeze.Implicit.Checkbox, %{checked: false, disabled: true}} =
             Breeze.Test.metadata(session).implicit_state["storybook"]

    Breeze.Test.event(session, "template_changed", %{value: "counter"})
    assert Breeze.Test.metadata(session).assigns.config.storybook
  end

  test "offers Timeline for every starter and disables it with Inspector" do
    session = start_wizard()
    on_exit(fn -> Breeze.Test.stop(session) end)

    Enum.each(~w(blank counter), fn template ->
      Breeze.Test.event(session, "template_changed", %{value: template})
      Breeze.Test.event(session, "timeline_changed", %{value: true})

      assert Breeze.Test.metadata(session).assigns.config.timeline
      assert Breeze.Test.metadata(session).assigns.config.breeze_dep == {:hex, "~> 0.5.0"}

      assert Breeze.Test.metadata(session).assigns.config.template ==
               String.to_existing_atom(template)
    end)

    Breeze.Test.event(session, "inspector_changed", %{value: false})
    refute Breeze.Test.metadata(session).assigns.config.inspector
    refute Breeze.Test.metadata(session).assigns.config.timeline
    Breeze.Test.render!(session)

    assert {Breeze.Implicit.Checkbox, %{checked: false, disabled: true}} =
             Breeze.Test.metadata(session).implicit_state["timeline"]

    Breeze.Test.event(session, "inspector_changed", %{value: true})
    Breeze.Test.render!(session)

    assert {Breeze.Implicit.Checkbox, %{disabled: false}} =
             Breeze.Test.metadata(session).implicit_state["timeline"]
  end

  test "offers the additional built-in themes" do
    session = start_wizard()
    on_exit(fn -> Breeze.Test.stop(session) end)

    Breeze.Test.render!(session)
    Breeze.ChildServer.set_focus(session.pid, "theme")
    Breeze.Test.input(session, "Enter")
    rendered = Breeze.Test.render!(session)

    assert rendered =~ "Commander"
    assert rendered =~ "Catppuccin"
    assert rendered =~ "Nord"
    assert rendered =~ "Solarized Light"
    assert rendered =~ "Solarized Dark"
  end

  test "opening a dropdown does not resize the dialog" do
    session = start_wizard()
    on_exit(fn -> Breeze.Test.stop(session) end)

    closed = Breeze.Test.render!(session)
    Breeze.ChildServer.set_focus(session.pid, "template")
    Breeze.Test.input(session, "Enter")
    opened = Breeze.Test.render!(session)

    refute opened =~ "An interactive counter with keyboard controls."

    assert opened =~ "Blank"
    assert opened =~ "Counter"
    assert opened =~ "Theme"
    assert panel_bottom_row(opened) == panel_bottom_row(closed)
  end

  test "an open dropdown receives clicks ahead of covered checkboxes" do
    session = start_wizard()
    on_exit(fn -> Breeze.Test.stop(session) end)

    Breeze.Test.render!(session)
    Breeze.ChildServer.set_focus(session.pid, "theme")
    Breeze.Test.input(session, "Enter")
    Breeze.Test.render!(session)

    mouse_targets = :sys.get_state(session.pid).mouse_targets

    checkbox_bounds =
      mouse_targets
      |> Map.take(~w(mouse inspector live-reload timeline storybook git deps-get))
      |> Map.values()

    {{item_id, item_bounds}, covered_bounds} =
      Enum.find_value(mouse_targets, fn {id, bounds} ->
        if String.starts_with?(id, "theme-item-") do
          case Enum.find(checkbox_bounds, &bounds_overlap?(bounds, &1)) do
            nil -> nil
            covered -> {{id, bounds}, covered}
          end
        end
      end)

    item_index =
      item_id
      |> String.replace_prefix("theme-item-", "")
      |> String.to_integer()

    Breeze.Test.input(session, %{
      "mouse" => %{
        "button" => "left",
        "action" => "press",
        "x" => max(item_bounds.left, covered_bounds.left),
        "y" => max(item_bounds.top, covered_bounds.top)
      }
    })

    assert Breeze.Test.metadata(session).assigns.config.theme ==
             Enum.at(Config.themes(), item_index)
  end

  test "toggling Git keeps focus on the Git checkbox" do
    session = start_wizard()
    on_exit(fn -> Breeze.Test.stop(session) end)

    Breeze.Test.render!(session)
    Breeze.ChildServer.set_focus(session.pid, "git")
    Breeze.Test.event(session, "git_changed", %{value: false})

    assert %{focused: "git", assigns: %{config: %{init_git: false}}} =
             Breeze.Test.metadata(session)
  end

  test "checkboxes use the highlight color for focus" do
    session = start_wizard()
    on_exit(fn -> Breeze.Test.stop(session) end)

    unfocused = Breeze.Test.render!(session)
    Breeze.ChildServer.set_focus(session.pid, "mouse")
    focused = Breeze.Test.render!(session)

    assert {:ok, acc, _box, _decorations} =
             Breeze.ChildServer.render_snapshot(session.pid, terminal: session.terminal)

    classes = element_classes(acc, "mouse")

    assert classes =~ "focus:text-primary"
    assert classes =~ "bg-panel"
    refute classes =~ "focus:bg-"
    refute classes =~ "focus:bold"
    assert element_classes(acc, "options-grid") =~ "bg-panel"

    primary_indicator = ~r/\e\[[0-9;]*38;2;131;165;152m\|x\| /
    panel_backed_indicator = ~r/\e\[48;2;50;48;47;38;2;131;165;152m\|x\| Mouse/

    refute unfocused =~ primary_indicator
    assert focused =~ primary_indicator
    assert focused =~ panel_backed_indicator
    assert strip_ansi(unfocused) =~ "[x] Mouse"
    assert strip_ansi(focused) =~ "|x| Mouse"
    refute strip_ansi(focused) =~ "[x] Mouse"
  end

  test "each checkbox click focuses and toggles it" do
    session = start_wizard()
    on_exit(fn -> Breeze.Test.stop(session) end)

    Breeze.Test.render!(session)
    bounds = :sys.get_state(session.pid).mouse_targets["mouse"]

    click = %{
      "mouse" => %{
        "button" => "left",
        "action" => "press",
        "x" => div(bounds.left + bounds.right, 2),
        "y" => div(bounds.top + bounds.bottom, 2)
      }
    }

    Breeze.Test.input(session, click)

    assert %{focused: "mouse", assigns: %{config: %{mouse: false}}} =
             Breeze.Test.metadata(session)

    assert {Breeze.Implicit.Checkbox, %{checked: false, disabled: false}} =
             Breeze.Test.metadata(session).implicit_state["mouse"]

    assert session |> Breeze.Test.render!() |> strip_ansi() =~ "| | Mouse"

    Breeze.Test.input(session, click)

    assert %{focused: "mouse", assigns: %{config: %{mouse: true}}} =
             Breeze.Test.metadata(session)

    assert session |> Breeze.Test.render!() |> strip_ansi() =~ "|x| Mouse"
  end

  test "a long project-name error stays inside the fixed dialog" do
    session = start_wizard()
    on_exit(fn -> Breeze.Test.stop(session) end)

    initial = Breeze.Test.render!(session)
    Breeze.Test.event(session, "name_changed", %{value: "Invalid-Project-Name"})
    Breeze.Test.event(session, "create", %{})
    rendered = Breeze.Test.render!(session)

    assert rendered =~ "project name must start with a lowercase letter"
    assert rendered =~ "Create project"
    assert panel_bottom_row(rendered) == panel_bottom_row(initial)
  end

  test "shows validation errors instead of closing" do
    session = start_wizard()
    on_exit(fn -> Breeze.Test.stop(session) end)

    Breeze.Test.event(session, "commit_message_changed", %{value: ""})
    Breeze.Test.event(session, "create", %{})

    assert Process.alive?(session.pid)
    rendered = Breeze.Test.render!(session)
    assert rendered =~ "commit message cannot be empty"
    assert rendered =~ "Create project"
    refute_received {:breeze_new, _result}
  end

  test "returns the selected configuration" do
    session = start_wizard()
    Breeze.Test.event(session, "template_changed", %{value: "blank"})
    Breeze.Test.event(session, "timeline_changed", %{value: true})
    Breeze.Test.event(session, "create", %{})

    assert_receive {:breeze_new, {:generate, config}}
    assert config.template == :blank
    assert config.timeline
    assert config.breeze_dep == {:hex, "~> 0.5.0"}
    refute Process.alive?(session.pid)
  end

  test "can be cancelled" do
    session = start_wizard()
    Breeze.Test.event(session, "cancel", %{})

    assert_receive {:breeze_new, :cancel}
    refute Process.alive?(session.pid)
  end

  test "accepts an initially empty project name" do
    {:ok, config} = Config.new("", allow_empty: true)

    session =
      Breeze.Test.start!(Wizard,
        size: {80, 24},
        start_opts: [config: config, caller: self()],
        theme: Breeze.Theme.builtin(:gruvbox)
      )

    on_exit(fn -> Breeze.Test.stop(session) end)

    assert %{focused: "name"} = Breeze.Test.metadata(session)
    assert Breeze.Test.render!(session) =~ "my_app"

    Breeze.Test.input(session, "f")
    assert %{assigns: %{config: %{app_name: "f"}}} = Breeze.Test.metadata(session)
  end

  test "uses responsive Breeze layouts when the terminal is resized" do
    target =
      Path.join(System.tmp_dir!(), "breeze_new_resize_#{System.unique_integer([:positive])}")

    {:ok, config} = Config.new("sample_app", target: target)

    session =
      Breeze.Test.start!(Wizard,
        size: {132, 40},
        start_opts: [config: config, caller: self()],
        theme: Breeze.Theme.builtin(:gruvbox)
      )

    on_exit(fn -> Breeze.Test.stop(session) end)

    assert %{assigns: %{breeze: %{breakpoint: "xl"}}} = Breeze.Test.metadata(session)

    resized = %{session | terminal: %{session.terminal | size: %{width: 48, height: 60}}}
    Breeze.Test.info(resized, :resize)

    assert %{assigns: %{breeze: %{breakpoint: "sm", terminal: %{width: 48, height: 60}}}} =
             Breeze.Test.metadata(session)

    rendered = resized |> Breeze.Test.render!() |> strip_ansi()
    rows = String.split(rendered, "\n")

    assert rendered =~ "Create a Breeze application"
    assert rendered =~ "Create"
    assert rendered =~ "Cancel"
    refute rendered =~ "Create project"
    refute rendered =~ "An interactive counter with keyboard controls."
    assert Enum.find_index(rows, &String.contains?(&1, "╭")) > 0
    assert Enum.find_index(rows, &String.contains?(&1, "╰")) < 58
  end

  test "keeps every control inside compact and wide layouts" do
    compact = start_wizard(size: {32, 24})
    wide = start_wizard(size: {80, 24})

    on_exit(fn ->
      Breeze.Test.stop(compact)
      Breeze.Test.stop(wide)
    end)

    compact_rendered = compact |> Breeze.Test.render!() |> strip_ansi()
    wide_rendered = wide |> Breeze.Test.render!() |> strip_ansi()
    compact_rows = String.split(compact_rendered, "\n")
    wide_rows = String.split(wide_rendered, "\n")

    assert compact_rendered =~ "[x] Git repo"
    assert compact_rendered =~ "[x] Live reload"
    assert compact_rendered =~ "[x] Storybook"
    assert compact_rendered =~ "[ ] Fetch deps"
    assert compact_rendered =~ ~r/Cache\s+\[ \] Dynamic/
    assert compact_rendered =~ ~r/Max MB\s+256/
    assert compact_rendered =~ "[ ] Dynamic"
    assert compact_rendered =~ "Create"
    assert compact_rendered =~ "Cancel"
    refute compact_rendered =~ "Create project"
    refute compact_rendered =~ "An interactive counter with keyboard controls."
    refute compact_rendered =~ "Esc"

    assert wide_rendered =~ "[x] Git repository"
    assert wide_rendered =~ "[x] Live reload"
    assert wide_rendered =~ "[x] Storybook"
    assert wide_rendered =~ "[ ] Run mix deps.get"
    assert wide_rendered =~ "Cache"
    assert wide_rendered =~ "Limit in MB"
    assert wide_rendered =~ "[ ] Dynamic with os_mon"
    assert wide_rendered =~ "Create project"
    assert wide_rendered =~ "An interactive counter with keyboard controls."
    refute wide_rendered =~ "Esc"

    target_row = Enum.find_index(compact_rows, &String.contains?(&1, "/tmp/"))
    starter_row = Enum.find_index(compact_rows, &String.contains?(&1, "Starter"))

    create_row =
      Enum.find_index(
        compact_rows,
        &(String.contains?(&1, "Create") and not String.contains?(&1, "application"))
      )

    cancel_row = Enum.find_index(compact_rows, &String.contains?(&1, "Cancel"))

    assert starter_row == target_row + 2
    assert cancel_row == create_row + 1

    assert dropdown_row(compact_rows, "Counter") =~ "▼"
    assert dropdown_row(wide_rows, "Counter") =~ "▼"

    assert Enum.all?(compact_rows, &(String.length(&1) == 32))
    assert Enum.all?(wide_rows, &(String.length(&1) == 80))
  end

  test "aligns text inputs, dropdowns, and the action bar" do
    compact = start_wizard(size: {32, 24})
    wide = start_wizard(size: {80, 24})

    on_exit(fn ->
      Breeze.Test.stop(compact)
      Breeze.Test.stop(wide)
    end)

    Enum.each([{compact, :compact}, {wide, :wide}], fn {session, layout} ->
      rendered = session |> Breeze.Test.render!() |> strip_ansi()
      rows = String.split(rendered, "\n")
      targets = :sys.get_state(session.pid).mouse_targets
      input = targets["name"]

      Enum.each(~w(template theme cache-size commit-message), fn field ->
        assert targets[field].left == input.left
        assert targets[field].width == input.width
      end)

      create = targets["create"]
      cancel = targets["cancel"]
      create_label = if layout == :wide, do: "Create project", else: "Create"

      assert cancel.right == input.right

      {create_text_left, create_text_width} =
        :binary.match(Enum.at(rows, create.top), create_label)

      {cancel_text_left, cancel_text_width} =
        :binary.match(Enum.at(rows, cancel.top), "Cancel")

      assert create_text_left >= create.left
      assert create_text_left + create_text_width - 1 <= create.right
      assert cancel_text_left >= cancel.left
      assert cancel_text_left + cancel_text_width - 1 <= cancel.right

      case layout do
        :compact ->
          assert create.left == input.left
          assert create.width == input.width
          assert cancel.left == input.left
          assert cancel.width == input.width

        :wide ->
          assert create.left > input.left
          assert create.top == cancel.top
          assert cancel.left == create.right + 2
      end
    end)
  end

  test "derives the dialog height from its content before applying the terminal cap" do
    session = start_wizard(size: {80, 40})
    on_exit(fn -> Breeze.Test.stop(session) end)

    initial = session |> Breeze.Test.render!() |> strip_ansi()
    initial_height = panel_height(initial)

    assert initial_height < 39

    Breeze.Test.event(session, "commit_message_changed", %{value: ""})
    Breeze.Test.event(session, "create", %{})

    with_error = session |> Breeze.Test.render!() |> strip_ansi()

    assert with_error =~ "commit message cannot be empty"
    assert panel_height(with_error) == initial_height + 2
  end

  test "scrolls the panel when the terminal is shorter than the form" do
    session = start_wizard(size: {40, 12})
    on_exit(fn -> Breeze.Test.stop(session) end)

    initial = session |> Breeze.Test.render!() |> strip_ansi()
    initial_rows = String.split(initial, "\n")

    assert initial =~ "Project name"
    assert initial =~ "Starter"
    assert initial =~ "Theme"
    assert initial =~ "Use F3 to cycle themes"
    refute initial =~ "│Create"
    assert panel_bottom_row(initial) == 10
    assert Enum.all?(initial_rows, &(String.length(&1) == 40))

    Breeze.ChildServer.set_focus(session.pid, "wizard-panel")
    assert %{focused: "wizard-panel"} = Breeze.Test.metadata(session)

    Breeze.Test.input(session, "End")
    scrolled = session |> Breeze.Test.render!() |> strip_ansi()

    refute scrolled =~ "Project name"
    refute scrolled =~ "Use F3 to cycle themes"
    assert scrolled =~ "Create"
    assert scrolled =~ "Cancel"
    assert panel_bottom_row(scrolled) == 10
  end

  test "mouse wheel scrolls the panel content with its scrollbar" do
    session = start_wizard(size: {40, 12})
    on_exit(fn -> Breeze.Test.stop(session) end)

    initial = session |> Breeze.Test.render!() |> strip_ansi()

    Breeze.Test.input(session, %{
      "mouse" => %{
        "button" => "wheel_down",
        "action" => "press",
        "x" => 2,
        "y" => 4
      }
    })

    assert {Breeze.Implicit.Scroll, %{offset_y: offset_y}} =
             Breeze.Test.metadata(session).implicit_state["wizard-panel"]

    assert offset_y > 0

    scrolled = session |> Breeze.Test.render!() |> strip_ansi()

    refute scrolled == initial
    refute scrolled =~ "Project name"
    assert scrolled =~ "Use F3 to cycle themes"
    assert panel_bottom_row(scrolled) == 10
  end

  test "opening a dropdown after scrolling does not duplicate it over the panel" do
    session = start_wizard(size: {80, 15})
    on_exit(fn -> Breeze.Test.stop(session) end)

    Breeze.Test.render!(session)

    Breeze.Test.input(session, %{
      "mouse" => %{
        "button" => "wheel_down",
        "action" => "press",
        "x" => 6,
        "y" => 4
      }
    })

    assert {Breeze.Implicit.Scroll, %{offset_y: offset_y}} =
             Breeze.Test.metadata(session).implicit_state["wizard-panel"]

    assert offset_y > 0

    Breeze.ChildServer.set_focus(session.pid, "theme")
    Breeze.Test.input(session, "Enter")
    opened = session |> Breeze.Test.render!() |> strip_ansi()
    rows = String.split(opened, "\n")

    assert opened =~ "Create a Breeze application"
    assert Enum.count(rows, &String.contains?(&1, "Theme")) == 1
    assert length(Regex.scan(~r/Gruvbox/, opened)) == 2
    assert panel_bottom_row(opened) == 13
    assert Enum.all?(rows, &(String.length(&1) == 80))
  end

  defp start_wizard(opts \\ []) do
    target =
      Path.join(System.tmp_dir!(), "breeze_new_wizard_#{System.unique_integer([:positive])}")

    {:ok, config} = Config.new("sample_app", target: target)

    Breeze.Test.start!(Wizard,
      size: Keyword.get(opts, :size, {80, 24}),
      start_opts: [config: config, caller: self()],
      theme: Breeze.Theme.builtin(:gruvbox)
    )
  end

  defp panel_bottom_row(rendered) do
    rendered
    |> String.split("\n")
    |> Enum.find_index(&String.contains?(&1, "╰"))
  end

  defp panel_height(rendered) do
    rows = String.split(rendered, "\n")
    top = Enum.find_index(rows, &String.contains?(&1, "╭"))
    bottom = Enum.find_index(rows, &String.contains?(&1, "╰"))

    bottom - top + 1
  end

  defp strip_ansi(rendered) do
    String.replace(rendered, ~r/\e\[[0-9;?]*[ -\/]*[@-~]/, "")
  end

  defp element_classes(acc, id) do
    acc.elements
    |> Map.values()
    |> Enum.find(&(Keyword.get(&1, :id) == id))
    |> Keyword.fetch!(:class)
    |> List.wrap()
    |> List.flatten()
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
  end

  defp dropdown_row(rows, selected) do
    Enum.find(rows, &(String.contains?(&1, selected) and String.contains?(&1, "▼")))
  end

  defp bounds_overlap?(left, right) do
    left.left <= right.right and left.right >= right.left and left.top <= right.bottom and
      left.bottom >= right.top
  end
end
