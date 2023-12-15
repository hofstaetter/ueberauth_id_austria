defmodule UeberauthIdAustria do
  @moduledoc """
  Überauth ID-Austria Application Module

  The application starts its supervisor and a configuration agent.
  """

  use Application
  
  @impl Application
  def start(_type, _args) do
    children = [
      UeberauthIdAustria.Config
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @impl Application
  def config_change(_changed, _new, _removed) do
    UeberauthIdAustria.Config.reload()
    :ok
  end
end

defmodule UeberauthIdAustria.Config do
  @moduledoc "Configuration Agent"

  use Agent

  def start_link(_) do
    config = load_config() 
    Agent.start_link(fn -> config end, name: __MODULE__)
  end

  @doc """
  Returns the configuration for the oauth client
  """

  @spec oauth() :: Keyword.t()
  def oauth() do
    Agent.get(__MODULE__, fn %{oauth_config: return} -> return end)
  end

  @doc """
  Returns the JWT verify key.
  """

  @spec verify_key() :: JOSE.JWK.t()
  def verify_key() do
    Agent.get(__MODULE__, fn %{verify_key: return} -> return end)
  end

  @doc """
  Reloads the configuration
  """

  @spec reload() :: :ok | {:error, term()}
  def reload() do
    new_config = load_config()
    Agent.update(__MODULE__, fn _ -> new_config end)
  rescue
    e in RuntimeError ->
      {:error, e.message}
  end

  # Fetches configuration for `Ueberauth.Strategy.IdAustria.OAuth` Strategy from `config.exs`
  # Also checks if at least `client_id` and `client_secret` are set, raising an error if not.
  defp load_config() do
    prod_mode? = Application.get_env(:ueberauth_id_austria, :prod, true)

    host =
      if prod_mode?,
        do: "eid.oesterreich.gv.at",
        else: "eid2.oesterreich.gv.at"

    default_config = [
      authorize_url: "https://#{host}/auth/idp/profile/oidc/authorize",
      token_url: "https://#{host}/auth/idp/profile/oidc/token",
      strategy: Ueberauth.Strategy.IdAustria.OAuth,
      token_method: :post,
      serializers: %{"application/json" => Jason}
    ]

    env_config =
      :ueberauth
      |> Application.fetch_env!(Ueberauth.Strategy.IdAustria.OAuth)
      |> check_config_key_exists(:client_id)
      |> check_config_key_exists(:client_secret)

    key_file =
      if prod_mode?,
        do: "P.crt",
        else: "Q.crt"

    verify_key =
      :ueberauth_id_austria
      |> :code.priv_dir()
      |> Path.join(key_file)
      |> JOSE.JWK.from_pem_file()

    oauth_config = Keyword.merge(default_config, env_config)

    %{
      oauth_config: oauth_config,
      verify_key: verify_key
    }
  end

  defp check_config_key_exists(config, key) when is_list(config) do
    unless Keyword.has_key?(config, key) do
      raise "#{inspect(key)} missing from config :ueberauth, Ueberauth.Strategy.IdAustria.OAuth"
    end

    config
  end

  defp check_config_key_exists(_, _) do
    raise "Config :ueberauth, Ueberauth.Strategy.IdAustria.OAuth is not a keyword list, as expected"
  end
end
