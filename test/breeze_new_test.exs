defmodule BreezeNewTest do
  use ExUnit.Case, async: true

  alias BreezeNew.Config

  test "delegates project generation" do
    target = tmp_target("public_api")
    on_exit(fn -> File.rm_rf(target) end)

    {:ok, config} = Config.new("sample_app", target: target, init_git: false)

    assert {:ok, %{target: ^target}} = BreezeNew.generate(config)
    assert File.exists?(Path.join(target, "mix.exs"))
  end

  defp tmp_target(name) do
    Path.join(System.tmp_dir!(), "breeze_new_#{name}_#{System.unique_integer([:positive])}")
  end
end
