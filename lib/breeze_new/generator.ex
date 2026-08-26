defmodule BreezeNew.Generator do
  @moduledoc "Safely writes a generated Breeze project to disk."

  alias BreezeNew.{Config, Template}

  @type result ::
          {:ok, %{target: String.t(), files: [String.t()], warnings: [String.t()]}}
          | {:error, String.t()}

  @spec generate(Config.t(), keyword()) :: result()
  def generate(%Config{} = config, opts \\ []) do
    with :ok <- Config.validate(config),
         {:ok, staging} <- staging_directory(config.target),
         {:ok, files} <- write_files(staging, Template.files(config)),
         :ok <- move_into_place(staging, config.target) do
      warnings = maybe_get_dependencies(config, opts) ++ maybe_initialize_git(config, opts)
      {:ok, %{target: config.target, files: files, warnings: warnings}}
    end
  end

  defp staging_directory(target) do
    staging = target <> ".breeze-new-#{System.unique_integer([:positive])}"

    case File.mkdir(staging) do
      :ok ->
        {:ok, staging}

      {:error, reason} ->
        {:error, "could not create staging directory: #{:file.format_error(reason)}"}
    end
  end

  defp write_files(staging, files) do
    result =
      Enum.reduce_while(files, [], fn {relative, content}, written ->
        path = Path.join(staging, relative)

        with :ok <- File.mkdir_p(Path.dirname(path)),
             :ok <- File.write(path, content) do
          {:cont, [relative | written]}
        else
          {:error, reason} ->
            File.rm_rf(staging)
            {:halt, {:error, "could not write #{relative}: #{:file.format_error(reason)}"}}
        end
      end)

    case result do
      {:error, _} = error -> error
      written -> {:ok, Enum.sort(written)}
    end
  end

  defp move_into_place(staging, target) do
    case File.rename(staging, target) do
      :ok ->
        :ok

      {:error, reason} ->
        File.rm_rf(staging)
        {:error, "could not create #{target}: #{:file.format_error(reason)}"}
    end
  end

  defp maybe_get_dependencies(%Config{deps_get: false}, _opts), do: []

  defp maybe_get_dependencies(%Config{} = config, opts) do
    mix = Keyword.get_lazy(opts, :mix, fn -> System.find_executable("mix") end)

    cond do
      is_nil(mix) ->
        ["Dependency fetching was requested but the mix executable was not found"]

      true ->
        case System.cmd(mix, ["deps.get"], cd: config.target, stderr_to_stdout: true) do
          {_, 0} ->
            []

          {output, _status} ->
            ["Project was generated, but mix deps.get failed: #{String.trim(output)}"]
        end
    end
  end

  defp maybe_initialize_git(%Config{init_git: false}, _opts), do: []

  defp maybe_initialize_git(%Config{} = config, opts) do
    git = Keyword.get_lazy(opts, :git, fn -> System.find_executable("git") end)

    cond do
      is_nil(git) ->
        ["Git was requested but the git executable was not found"]

      true ->
        with {_, 0} <- System.cmd(git, ["init"], cd: config.target, stderr_to_stdout: true),
             {_, 0} <- System.cmd(git, ["add", "."], cd: config.target, stderr_to_stdout: true),
             {_, 0} <-
               System.cmd(git, ["commit", "-m", config.commit_message],
                 cd: config.target,
                 stderr_to_stdout: true
               ) do
          []
        else
          {output, _status} ->
            [
              "Project was generated, but Git initialization did not complete: #{String.trim(output)}"
            ]
        end
    end
  end
end
