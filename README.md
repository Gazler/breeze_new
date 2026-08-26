# BreezeNew

`breeze_new` creates a ready-to-run [Breeze](https://github.com/Gazler/breeze)
terminal application through an interactive TUI wizard.

The wizard lets you choose a minimal Blank project or an example Counter, List,
Kitchen Sink, or SSH starter, along with the theme, F3 theme cycling, mouse
support, development inspector, render-cache sizing, optional Timeline and
live-reload support, and optional Git initialization.
Generation can also weave a reusable function component and Storybook story
into the Counter, List, Kitchen Sink, and SSH starters. It is staged in a
temporary directory so an existing target is never overwritten.
Generated projects derive their Elixir requirement from the runtime executing
`breeze_new`, including prerelease versions.

## Build

```bash
mix deps.get
mix escript.build
```

Development and release builds use Breeze `~> 0.5.0` and BackBreeze
`~> 0.4.4` from Hex. Generated projects also declare all dependencies as Hex
requirements.

## Create an application

Start the wizard with an empty project name, or pre-fill it with a name or path:

```bash
mix run
mix run -- my_app

# Or use the built escript:
./breeze_new
./breeze_new my_app
./breeze_new apps/my_app
```

Use `Tab` and `Shift+Tab` to move between controls, `Enter` to open dropdowns or
activate buttons, and `Space` or a left click to toggle checkboxes.

For scripts and CI, bypass the wizard:

```bash
./breeze_new my_app \
  --no-tui \
  --template list \
  --theme system \
  --cache-size dynamic \
  --deps-get \
  --no-inspector \
  --no-live-reload \
  --no-storybook \
  --no-git
```

Run `./breeze_new --help` for every option.

## Run the generated project

```bash
cd my_app
mix deps.get
mix run --no-halt
```

Generated projects include a Breeze view test, environment-specific
configuration, a production-safe error view, optional development live
reloading, an optional component Storybook for example starters, theme cycling
on `F3`, and quit handling on `q`.

The render cache defaults to a fixed 256 MB limit, avoiding a dependency on
OTP's `:memsup`. Choose `dynamic` in the wizard or pass `--cache-size dynamic`
to start `:os_mon` and let BackBreeze size the cache from available system
memory. A different positive MB value sets an explicit limit instead.

When Storybook is selected for the Counter, List, Kitchen Sink, or SSH starter,
launch it with:

```bash
mix breeze.storybook
```

Timeline can be enabled for any starter in the wizard or with `--timeline`. It
records development renders with
[`breeze_timeline`](https://hex.pm/packages/breeze_timeline). Start the generated
application, then inspect and rewind it from another terminal:

```bash
mix breeze.inspector
```

Timeline recording is configured only for development; the generated
production configuration disables the inspector.

The SSH starter uses `Termite.SSH.terminal/1` to give every connection an
independent Breeze view. Generate a development host key, start the listener,
and connect without authentication on the loopback interface:

```bash
mix termite.ssh.gen_host_key
mix run --no-halt
ssh -o PreferredAuthentications=none -o PubkeyAuthentication=no -p 2222 demo@localhost
```

Run the same generated view without starting SSH using `mix my_app.local`.
Generated production runtime configuration requires a provisioned host-key
directory and an OpenSSH `authorized_keys` directory; the no-auth setting is
limited to development and test configuration.

## Development

Run any non-SSH starter directly from the current templates without generating
a project or writing files:

```bash
mix breeze_new.preview blank
mix breeze_new.preview counter
mix breeze_new.preview list
mix breeze_new.preview kitchen_sink
```

Preview modules are compiled in memory and unloaded when the view exits. Press
`F3` to cycle themes, `F4` for the local inspector, and `q` to quit.

```bash
mix test
mix format --check-formatted
```
