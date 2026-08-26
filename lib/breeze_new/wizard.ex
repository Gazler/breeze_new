defmodule BreezeNew.Wizard do
  @moduledoc false

  use Breeze.View
  import Breeze.Blocks

  alias BreezeNew.Config

  @footer_height 1
  @panel_chrome_height 3

  @impl true
  def mount(opts, term) do
    config = Keyword.fetch!(opts, :config)
    target_parent = if config.app_name == "", do: config.target, else: Path.dirname(config.target)

    {:ok,
     term
     |> focus("name")
     |> assign(
       config: config,
       target_parent: target_parent,
       caller: Keyword.fetch!(opts, :caller),
       error: nil,
       cache_size_input: cache_size_input(config.cache_size),
       templates: choices(Config.templates()),
       themes: choices(Config.themes()),
       starter_description: starter_description(config.template)
     )
     |> put_local_keybindings([
       {"Tab", "Next field"},
       {"Space", "Toggle"},
       {"Enter", "Create"}
     ])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <box class="grid grid-cols-1 grid-rows-2 width-screen height-screen bg">
      <box class="width-full height-full">
        <.panel
          id="wizard-panel"
          scroll
          class={panel_class()}
          scroll_class="width-full height-auto"
          scroll_style={panel_scroll_style(@breeze.terminal)}
          title_class="text-primary bold"
        >
          <:title>Create a Breeze application</:title>

          <box class="width-full">
            <.form_row label="Project name">
              <.input
                id="name"
                input-value={@config.app_name}
                input-placeholder="my_app"
                br-change="name_changed"
                class="width-full"
              />
            </.form_row>

            <box class="text-muted width-full height-1 overflow-hidden">{@config.target}</box>

            <box class="height-1"></box>

            <.form_row label="Starter">
              <.dropdown
                id="template"
                selected={Atom.to_string(@config.template)}
                br-change="template_changed"
                class="width-full"
              >
                <:item :for={template <- @templates} value={template.value}>
                  {template.label}
                </:item>
              </.dropdown>
            </.form_row>
            <box class="hidden md:block">
              <box class="text-muted width-full md:padding-left-16 md:width-54 lg:padding-left-18 lg:width-66">
                {@starter_description}
              </box>
            </box>
            <box class="hidden sm:block sm:height-1"></box>

            <.form_row label="Theme">
              <.dropdown
                id="theme"
                selected={Atom.to_string(@config.theme)}
                br-change="theme_changed"
                class="width-full"
              >
                <:item :for={theme <- @themes} value={theme.value}>
                  {theme.label}
                </:item>
              </.dropdown>
            </.form_row>
            <box class="width-full md:padding-left-16 md:width-54 lg:padding-left-18 lg:width-66">
              <.checkbox
                id="theme-cycle"
                class="width-full"
                checked={@config.theme_cycle}
                br-change="theme_cycle_changed"
              >
                Use F3 to cycle themes
              </.checkbox>
            </box>
            <box class="height-1"></box>

            <.form_sections
              config={@config}
              error={@error}
              cache_size_input={@cache_size_input}
              breakpoint={@breeze.breakpoint}
            />
          </box>
        </.panel>
      </box>

      <box class="height-1 width-full overflow-hidden bg-panel">
        <box class="inline sm:hidden width-full height-1 overflow-hidden padding-left-1">
          <box class="text-accent bold">Tab</box>
          <box> · </box>
          <box class="text-accent bold">Space</box>
          <box> · </box>
          <box class="text-accent bold">Enter</box>
        </box>
        <box
          class="hidden sm:inline md:hidden width-full height-1 overflow-hidden padding-left-1"
        >
          <box class="text-accent bold">Tab</box>
          <box> · </box>
          <box class="text-accent bold">Space</box>
          <box> Toggle · </box>
          <box class="text-accent bold">Enter</box>
          <box> Create</box>
        </box>
        <.keybinding_bar
          keybindings={@breeze.keybindings}
          class="hidden md:inline width-full height-1 overflow-hidden bg-panel padding-left-1 padding-right-1"
        />
      </box>
    </box>
    """
  end

  attr(:label, :string, required: true)
  slot(:inner_block, required: true)

  def form_row(assigns) do
    ~H"""
    <box class="inline width-full height-1">
      <box class="text-muted width-13 md:width-16 lg:width-18 height-1">
        {if @label == "", do: " ", else: @label}
      </box>
      <box class="width-16 sm:width-25 md:width-38 lg:width-48 height-1">
        {render_slot(@inner_block)}
      </box>
    </box>
    """
  end

  attr(:config, :map, required: true)
  attr(:error, :any, default: nil)
  attr(:cache_size_input, :string, required: true)
  attr(:breakpoint, :string, required: true)

  def form_sections(assigns) do
    ~H"""
    <.options_section config={@config} breakpoint={@breakpoint} />

    <box class="height-1"></box>

    <.cache_section
      config={@config}
      cache_size_input={@cache_size_input}
      breakpoint={@breakpoint}
    />

    <box class="height-1"></box>

    <.git_section config={@config} breakpoint={@breakpoint} />

    <box class="height-1"></box>

    <box :if={@error} class="text-error width-full height-2 overflow-hidden">{@error}</box>

    <.form_actions breakpoint={@breakpoint} />
    """
  end

  attr(:config, :map, required: true)
  attr(:breakpoint, :string, required: true)

  def options_section(assigns) do
    # BackBreeze's nested-grid render path currently drops inherited backgrounds, so the
    # checkbox cells also carry bg-panel explicitly.
    ~H"""
    <box class="width-full bg-panel md:grid md:grid-cols-2">
      <box class="text-muted width-full height-1 md:width-16 lg:width-18">
        Options
      </box>
      <box
        id="options-grid"
        class="grid grid-cols-2 width-full bg-panel md:width-38 lg:width-48"
      >
        <.checkbox
          id="mouse"
          class="width-full bg-panel"
          checked={@config.mouse}
          br-change="mouse_changed"
        >
          Mouse
        </.checkbox>
        <.checkbox
          id="inspector"
          class="width-full bg-panel"
          checked={@config.inspector}
          br-change="inspector_changed"
        >
          Inspector
        </.checkbox>
        <.checkbox
          id="live-reload"
          class="width-full bg-panel"
          checked={@config.live_reload}
          br-change="live_reload_changed"
        >
          Live reload
        </.checkbox>
        <.checkbox
          id="timeline"
          class="width-full bg-panel"
          checked={@config.timeline}
          disabled={!@config.inspector}
          br-change="timeline_changed"
        >
          Timeline
        </.checkbox>
        <.checkbox
          id="storybook"
          class="width-full bg-panel"
          checked={@config.storybook}
          disabled={@config.template == :blank}
          br-change="storybook_changed"
        >
          Storybook
        </.checkbox>
        <.checkbox
          id="deps-get"
          class="width-full bg-panel"
          checked={@config.deps_get}
          br-change="deps_get_changed"
        >
          {wide_label(@breakpoint, "Run mix deps.get", "Fetch deps")}
        </.checkbox>
      </box>
    </box>
    """
  end

  attr(:config, :map, required: true)
  attr(:cache_size_input, :string, required: true)
  attr(:breakpoint, :string, required: true)

  def cache_section(assigns) do
    ~H"""
    <.form_row label="Cache">
      <.checkbox
        id="dynamic-cache"
        class="width-full"
        checked={@config.cache_size == :dynamic}
        br-change="dynamic_cache_changed"
      >
        {wide_label(@breakpoint, "Dynamic with os_mon", "Dynamic")}
      </.checkbox>
    </.form_row>
    <.form_row
      :if={@config.cache_size != :dynamic}
      label={wide_label(@breakpoint, "Limit in MB", "Max MB")}
    >
      <.input
        id="cache-size"
        input-value={@cache_size_input}
        input-placeholder="256"
        br-change="cache_size_changed"
        class="width-full"
      />
    </.form_row>
    <box :if={@config.cache_size == :dynamic} class="height-1"></box>
    """
  end

  attr(:config, :map, required: true)
  attr(:breakpoint, :string, required: true)

  def git_section(assigns) do
    ~H"""
    <.form_row label="Git">
      <.checkbox
        id="git"
        class="width-full"
        checked={@config.init_git}
        br-change="git_changed"
      >
        {wide_label(@breakpoint, "Git repository", "Git repo")}
      </.checkbox>
    </.form_row>
    <.form_row label="">
      <.input
        :if={@config.init_git}
        id="commit-message"
        input-value={@config.commit_message}
        input-placeholder="Initial commit"
        br-change="commit_message_changed"
        class="width-full"
      />
      <box :if={!@config.init_git} class="text-muted width-full">
        Git initialization disabled
      </box>
    </.form_row>
    """
  end

  attr(:breakpoint, :string, required: true)

  def form_actions(assigns) do
    ~H"""
    <box class="inline width-full height-2 sm:height-1">
      <box class="width-13 height-2 sm:width-13 sm:height-1 md:width-16 lg:width-18 bg-panel content-repeat"> </box>
      <box class="inline width-16 sm:width-25 md:width-38 lg:width-48 bg-panel">
        <box class="hidden sm:block sm:width-8 md:width-11 lg:width-14 sm:height-1 bg-panel content-repeat"> </box>
        <box class="grid grid-cols-1 sm:grid-cols-2 sm:gap-x-1 width-full bg-panel">
          <.button
            id="create"
            br-click="create"
            class="width-full padding-left-0 padding-right-0 sm:padding-left-1 sm:padding-right-1"
          >
            {create_label(@breakpoint)}
          </.button>
          <.button
            id="cancel"
            br-click="cancel"
            class="width-full padding-left-0 padding-right-0 sm:padding-left-1 sm:padding-right-1 bg-error text-bg"
          >
            Cancel
          </.button>
        </box>
      </box>
    </box>
    """
  end

  @impl true
  def handle_event("name_changed", %{value: value}, term) do
    config = term.assigns.config
    app_name = String.trim(value)

    updated = %{
      config
      | app_name: app_name,
        module_name: Macro.camelize(app_name),
        target: Path.expand(Path.join(term.assigns.target_parent, app_name))
    }

    {:noreply, assign(term, config: updated, error: nil)}
  end

  def handle_event("template_changed", %{value: value}, term) do
    template = existing_atom(value, Config.templates())

    storybook =
      cond do
        template == :blank -> false
        term.assigns.config.template == :blank -> true
        true -> term.assigns.config.storybook
      end

    {:noreply,
     term
     |> update_config(:template, template)
     |> update_config(:storybook, storybook)
     |> Breeze.View.reset("storybook")
     |> assign(starter_description: starter_description(template))}
  end

  def handle_event("theme_changed", %{value: value}, term) do
    theme = existing_atom(value, Config.themes())

    term =
      term
      |> update_config(:theme, theme)
      |> Breeze.View.switch_theme(theme)

    {:noreply, term}
  end

  def handle_event("commit_message_changed", %{value: value}, term),
    do: {:noreply, update_config(term, :commit_message, value)}

  def handle_event("cache_size_changed", %{value: value}, term) do
    term = assign(term, cache_size_input: value, error: nil)

    case parse_fixed_cache_size(value) do
      {:ok, cache_size} when term.assigns.config.cache_size != :dynamic ->
        {:noreply, update_config(term, :cache_size, cache_size)}

      {:ok, _cache_size} ->
        {:noreply, term}

      {:error, _message} ->
        {:noreply, term}
    end
  end

  def handle_event("dynamic_cache_changed", %{value: true}, term) do
    {:noreply,
     term
     |> update_config(:cache_size, :dynamic)
     |> Breeze.View.reset("cache-size")}
  end

  def handle_event("dynamic_cache_changed", %{value: false}, term) do
    case parse_fixed_cache_size(term.assigns.cache_size_input) do
      {:ok, cache_size} ->
        {:noreply,
         term
         |> update_config(:cache_size, cache_size)
         |> Breeze.View.reset("cache-size")}

      {:error, message} ->
        {:noreply, assign(term, error: message)}
    end
  end

  def handle_event("theme_cycle_changed", %{value: value}, term),
    do: {:noreply, update_config(term, :theme_cycle, value)}

  def handle_event("mouse_changed", %{value: value}, term),
    do: {:noreply, update_config(term, :mouse, value)}

  def handle_event("inspector_changed", %{value: value}, term) do
    term = update_config(term, :inspector, value)

    term =
      if value do
        term
      else
        put_timeline(term, false)
      end

    {:noreply, Breeze.View.reset(term, "timeline")}
  end

  def handle_event("timeline_changed", %{value: value}, term),
    do: {:noreply, put_timeline(term, value)}

  def handle_event("live_reload_changed", %{value: value}, term),
    do: {:noreply, update_config(term, :live_reload, value)}

  def handle_event("storybook_changed", %{value: value}, term),
    do: {:noreply, update_config(term, :storybook, value)}

  def handle_event("git_changed", %{value: value}, term),
    do: {:noreply, update_config(term, :init_git, value)}

  def handle_event("deps_get_changed", %{value: value}, term),
    do: {:noreply, update_config(term, :deps_get, value)}

  def handle_event("create", _event, term), do: finish(term)
  def handle_event("cancel", _event, term), do: cancel(term)

  def handle_event(_, %{"key" => "Enter"}, %{focused: "create"} = term), do: finish(term)
  def handle_event(_, %{"key" => "Enter"}, %{focused: "cancel"} = term), do: cancel(term)
  def handle_event(_, _, term), do: {:noreply, term}

  @impl true
  def handle_info(_message, term), do: {:noreply, term}

  defp finish(term) do
    with {:ok, config} <- put_fixed_cache_size(term.assigns.config, term.assigns.cache_size_input),
         :ok <- Config.validate(config) do
      send(term.assigns.caller, {:breeze_new, {:generate, config}})
      {:stop, term}
    else
      {:error, message} ->
        {:noreply, show_error(term, message)}
    end
  end

  defp cancel(term) do
    send(term.assigns.caller, {:breeze_new, :cancel})
    {:stop, term}
  end

  defp update_config(term, key, value) do
    assign(term, config: Map.replace!(term.assigns.config, key, value), error: nil)
  end

  defp show_error(term, message) do
    term
    |> assign(error: message)
    |> Breeze.View.put_implicit("wizard-panel", Breeze.Implicit.Scroll, %{
      offset_y: 0,
      autoscroll: "bottom",
      pinned_bottom: true
    })
  end

  defp put_timeline(term, enabled) do
    assign(term, config: Config.put_timeline(term.assigns.config, enabled), error: nil)
  end

  defp existing_atom(value, choices), do: Enum.find(choices, &(Atom.to_string(&1) == value))

  defp create_label(breakpoint) when breakpoint in ["lg", "xl", "2xl"], do: "Create project"
  defp create_label(_breakpoint), do: "Create"

  defp wide_label(breakpoint, label, _compact_label)
       when breakpoint in ["lg", "xl", "2xl"],
       do: label

  defp wide_label(_breakpoint, _label, compact_label), do: compact_label

  defp cache_size_input(:dynamic), do: "256"
  defp cache_size_input(size), do: Integer.to_string(size)

  defp put_fixed_cache_size(%Config{cache_size: :dynamic} = config, _value), do: {:ok, config}

  defp put_fixed_cache_size(config, value) do
    with {:ok, cache_size} <- parse_fixed_cache_size(value) do
      {:ok, Map.replace!(config, :cache_size, cache_size)}
    end
  end

  defp parse_fixed_cache_size(value) do
    case Config.parse_cache_size(value) do
      {:ok, size} when is_integer(size) -> {:ok, size}
      _other -> {:error, "cache size must be a positive integer in MB"}
    end
  end

  defp panel_class do
    "absolute center width-screen md:width-58 lg:width-72 height-auto padding-top-1"
  end

  defp panel_scroll_style(%{height: height}) when is_integer(height) do
    %{max_height: max(height - @footer_height - @panel_chrome_height, 1)}
  end

  defp panel_scroll_style(_terminal), do: %{}

  defp starter_description(:counter),
    do: "An interactive counter with keyboard controls."

  defp starter_description(:blank),
    do: "A minimal Breeze view with no example interface."

  defp starter_description(:list),
    do: "A selectable task list with focus and events."

  defp starter_description(:kitchen_sink),
    do: "A gallery of every Breeze component."

  defp choices(values) do
    Enum.map(values, fn value ->
      %{value: Atom.to_string(value), label: choice_label(value)}
    end)
  end

  defp choice_label(:kitchen_sink), do: "Kitchen Sink"

  defp choice_label(value) do
    value
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
