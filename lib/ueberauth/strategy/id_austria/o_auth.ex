defmodule Ueberauth.Strategy.IdAustria.OAuth do
  @moduledoc """
  An implementation of OAuth2 for ID Austria.

  To add your `client_id` and `client_secret` include these values in your configuration.

      config :ueberauth, Ueberauth.Strategy.IdAustria.OAuth,
        client_id: System.get_env("EID_CLIENT_ID"),
        client_secret: System.get_env("EID_CLIENT_SECRET")
  """
  use OAuth2.Strategy

  @host if Mix.env() == :prod, do: "eid.oesterreich.gv.at", else: "eid2.oesterreich.gv.at"

  @defaults [
    strategy: __MODULE__,
    authorize_url: "https:/#{@host}//auth/idp/profile/oidc/authorize",
    token_url: "https://#{@host}/auth/idp/profile/oidc/token",
    token_method: :post,
    serializers: %{"application/json" => Jason}
  ]

  @doc """
  Construct a client for requests to ID Austria.

  Optionally include any OAuth2 options here to be merged with the defaults.

      Ueberauth.Strategy.IdAustria.OAuth.client(redirect_uri: "http://localhost:4000/auth/eid/callback")

  This will be setup automatically for you in `Ueberauth.Strategy.IdAustria`.
  These options are only useful for usage outside the normal callback phase of Ueberauth.
  """
  def client(opts \\ []) do
    client_opts =
      @defaults
      |> Keyword.merge(config())
      |> Keyword.merge(opts)

    OAuth2.Client.new(client_opts)
  end

  # Fetches configuration for `Ueberauth.Strategy.IdAustria.OAuth` Strategy from `config.exs`
  # Also checks if at least `client_id` and `client_secret` are set, raising an error if not.
  defp config() do
    :ueberauth
    |> Application.fetch_env!(Ueberauth.Strategy.IdAustria.OAuth)
    |> check_config_key_exists(:client_id)
    |> check_config_key_exists(:client_secret)
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth. No need to call this usually.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client
    |> OAuth2.Client.authorize_url!(params)
  end

  def get(token, url, headers \\ [], opts \\ []) do
    [token: token]
    |> client
    |> put_param("access_token", token)
    |> OAuth2.Client.get(url, headers, opts)
  end

  def get_token!(params \\ [], options \\ []) do
    headers = Keyword.get(options, :headers, [])
    options = Keyword.get(options, :options, [])
    client_options = Keyword.get(options, :client_options, [])
    client = OAuth2.Client.get_token!(client(client_options), params, headers, options)
    client.token
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    client
    |> put_param("response_type", "code")
    |> put_param("redirect_uri", client().redirect_uri)

    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    {code, params} = Keyword.pop(params, :code, client.params["code"])

    unless code do
      raise OAuth2.Error, reason: "Missing required key `code` for `#{inspect(__MODULE__)}`"
    end

    client
    |> put_param("client_id", client().client_id)
    |> put_param("client_secret", client().client_secret)
    |> put_param("grant_type", "authorization_code")
    |> put_param("redirect_uri", client().redirect_uri)
    |> put_header("Accept", "application/json")
    |> put_param(:code, code)
    |> put_param(:grant_type, "authorization_code")
    |> put_param(:client_id, client.client_id)
    |> put_param(:redirect_uri, client.redirect_uri)
    |> merge_params(params)
    |> put_headers(headers)
  end

  defp check_config_key_exists(config, key) when is_list(config) do
    unless Keyword.has_key?(config, key) do
      raise "#{inspect(key)} missing from config :ueberauth, Ueberauth.Strategy.IdAustria"
    end

    config
  end

  defp check_config_key_exists(_, _) do
    raise "Config :ueberauth, Ueberauth.Strategy.IdAustria is not a keyword list, as expected"
  end
end
