defmodule BreezeNew.TemplateTest do
  use ExUnit.Case, async: true

  alias BreezeNew.{Config, Template}

  @templates_root Path.expand("../../priv/templates", __DIR__)

  test "stores shared and project templates as EEx files under priv" do
    assert File.dir?(Path.join(@templates_root, "common"))
    assert File.dir?(Path.join(@templates_root, "projects"))

    for starter <- Config.templates() do
      assert File.dir?(Path.join([@templates_root, "projects", Atom.to_string(starter)]))
    end

    files = regular_files(@templates_root)

    assert files != []
    assert Enum.all?(files, &String.ends_with?(&1, ".eex"))
  end

  test "renders every starter without leaving generator EEx directives behind" do
    for starter <- Config.templates() do
      target = Path.join(System.tmp_dir!(), "breeze_new_template_#{starter}")
      {:ok, config} = Config.new("sample_app", target: target, template: starter)

      files = Template.files(config)

      assert map_size(files) > 0
      refute Enum.any?(files, fn {_path, contents} -> String.contains?(contents, "<%") end)

      refute Enum.any?(files, fn {_path, contents} ->
               Regex.match?(~r/\b(?:attr|slot)\(/, contents)
             end)
    end
  end

  test "uses Tailwind-style sizing, spacing, and font utilities" do
    legacy_utility =
      ~r/(?<![\w-])(?:width|height|padding(?:-(?:top|right|bottom|left|x|y))?)-/

    for starter <- Config.templates() do
      target = Path.join(System.tmp_dir!(), "breeze_new_tailwind_#{starter}")
      {:ok, config} = Config.new("sample_app", target: target, template: starter)

      for {path, contents} <- Template.files(config) do
        refute contents =~ legacy_utility, "found a legacy utility in #{path}"

        refute Regex.match?(~r/(?<![\w-])bold(?![\w-])/, contents),
               "found the legacy bold utility in #{path}"
      end
    end
  end

  defp regular_files(directory) do
    directory
    |> File.ls!()
    |> Enum.flat_map(fn entry ->
      path = Path.join(directory, entry)
      if File.dir?(path), do: regular_files(path), else: [path]
    end)
  end
end
