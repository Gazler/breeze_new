# BreezeNew

`breeze_new` creates a ready-to-run [Breeze](https://github.com/Gazler/breeze)
terminal application through an interactive TUI wizard.

The wizard lets you choose a minimal project scaffold and theme.

## Install

```bash
mix escript.install hex breeze_new
```

## Create an application

Start the wizard with an empty project name, or pre-fill it with a name or path:

```bash
breeze_new
```

To bypass the TUI, flags are available:

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

Run `breeze_new --help` for every option.

## Run the generated project

```bash
cd my_app
mix deps.get
mix run
```

Generated projects include a Breeze view test, environment-specific
configuration, a production-safe error view, optional development live
reloading, an optional component Storybook for example starters.

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
mix run
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
