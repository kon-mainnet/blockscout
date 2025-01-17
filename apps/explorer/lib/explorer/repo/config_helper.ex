defmodule Explorer.Repo.ConfigHelper do
  @moduledoc """
  Extracts values from environment and adds them to application config.

  Notably, this module processes the DATABASE_URL environment variable and extracts discrete parameters.

  The priority of vars is postgrex environment vars < DATABASE_URL components, with values being overwritten by higher priority.
  """

  # https://hexdocs.pm/postgrex/Postgrex.html#start_link/1-options
  @postgrex_env_vars [
    username: "PGUSER",
    password: "PGPASSWORD",
    host: "PGHOST",
    port: "PGPORT",
    database: "PGDATABASE"
  ]

  def get_db_config(opts) do
    url_encoded = opts[:url] || System.get_env("DATABASE_URL")
    url = url_encoded && URI.decode(url_encoded)
    env_function = opts[:env_func] || (&System.get_env/1)

    @postgrex_env_vars
    |> get_env_vars(env_function)
    |> Keyword.merge(extract_parameters(url))
  end

  def get_account_db_url, do: System.get_env("ACCOUNT_DATABASE_URL") || System.get_env("DATABASE_URL")

  def get_suave_db_url, do: System.get_env("SUAVE_DATABASE_URL") || System.get_env("DATABASE_URL")

  def get_api_db_url, do: System.get_env("DATABASE_READ_ONLY_API_URL") || System.get_env("DATABASE_URL")

  def init_repo_module(module, opts) do
    db_url = Application.get_env(:explorer, module)[:url]
    repo_conf = Application.get_env(:explorer, module)

    merged =
      %{url: db_url}
      |> get_db_config()
      |> Keyword.merge(repo_conf, fn
        _key, v1, nil -> v1
        _key, nil, v2 -> v2
        _, _, v2 -> v2
      end)

    Application.put_env(:explorer, module, merged)

    {:ok, Keyword.put(opts, :url, db_url)}
  end

  def ssl_enabled?, do: String.equivalent?(System.get_env("ECTO_USE_SSL") || "true", "true")

  defp extract_parameters(empty) when empty == nil or empty == "", do: []

  # sobelow_skip ["DOS.StringToAtom"]
  defp extract_parameters(database_url) do
    ~r/\w*:\/\/(?<username>[a-zA-Z0-9_-]*):(?<password>[a-zA-Z0-9-*#!%^&$_.]*)?@(?<hostname>[a-zA-Z0-9-*#!%^&$_.]*):(?<port>\d+)\/(?<database>[a-zA-Z0-9_-]*)/
    |> Regex.named_captures(database_url)
    |> Keyword.new(fn {k, v} -> {String.to_atom(k), v} end)
    |> Keyword.put(:url, database_url)
  end

  defp get_env_vars(vars, env_function) do
    Enum.reduce(vars, [], fn {name, var}, opts ->
      case env_function.(var) do
        nil -> opts
        "" -> opts
        env_value -> Keyword.put(opts, name, env_value)
      end
    end)
  end

  def network_path do
    path = System.get_env("NETWORK_PATH", "/")

    path_from_env(path)
  end

  @doc """
  Defines http port of the application
  """
  @spec get_port() :: non_neg_integer()
  def get_port do
    case System.get_env("PORT") && Integer.parse(System.get_env("PORT")) do
      {port, _} -> port
      _ -> 4000
    end
  end

  defp path_from_env(path_env_var) do
    if String.ends_with?(path_env_var, "/") do
      path_env_var
    else
      path_env_var <> "/"
    end
  end
end
