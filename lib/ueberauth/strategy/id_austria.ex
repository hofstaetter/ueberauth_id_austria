defmodule Ueberauth.Strategy.IdAustria do
  @moduledoc """
  Provides an Ueberauth strategy for authenticating with ID Austria (the austrian eIDAS implementation).
  See the [eIDAS Regulation](https://digital-strategy.ec.europa.eu/en/policies/eidas-regulation) for infos about eIDAS.

  ### Setup

  You need to register your application with the austrian government.

  Information about registering can be obtained [from the EGIZ](https://eid.egiz.gv.at/anbindung/registrierung/).

  Include the provider in your configuration for Ueberauth

      config :ueberauth, Ueberauth,
        providers: [
          eid: { Ueberauth.Strategy.IdAustria, [] }
        ]

  Then include the configuration:

      config :ueberauth, Ueberauth.Strategy.IdAustria.OAuth,
        client_id: System.get_env("EID_CLIENT_ID"),
        client_secret: System.get_env("EID_CLIENT_SECRET")

  If you haven't already, create a pipeline and setup routes for your callback handler

      pipeline :auth do
        Ueberauth.plug "/auth"
      end

      scope "/auth" do
        pipe_through [:browser, :auth]

        get "/:provider/callback", AuthController, :callback
      end


  Create an endpoint for the callback where you will handle the `Ueberauth.Auth` struct

      defmodule MyApp.AuthController do
        use MyApp.Web, :controller

        def callback_phase(%{ assigns: %{ ueberauth_failure: fails } } = conn, _params) do
          # do things with the failure
        end

        def callback_phase(%{ assigns: %{ ueberauth_auth: auth } } = conn, params) do
          # do things with the auth
        end
      end
  """
  require Logger

  use Ueberauth.Strategy,
    uid_field: :id,
    default_scope: "openid profile eid",
    oauth2_module: Ueberauth.Strategy.IdAustria.OAuth

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra
  alias Ueberauth.Strategy.Helpers

  @doc """
  Handles the initial redirect to the ID Austria authentication page.

  The request will include the state parameter that was set by ueberauth (if available)
  """
  def handle_request!(conn) do
    opts =
      [
        redirect_uri: callback_url(conn),
        scope: option(conn, :default_scope)
      ]
      |> Helpers.with_state_param(conn)

    module = option(conn, :oauth2_module)
    redirect!(conn, apply(module, :authorize_url!, [opts]))
  end

  @doc """
  Handles the callback from ID Austria. When there is a failure the failure is included in the
  `ueberauth_failure` struct. Otherwise the information returned is returned in the `Ueberauth.Auth` struct.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    module = option(conn, :oauth2_module)

    token = apply(module, :get_token!, [[code: code, redirect_uri: callback_url(conn)]])

    if token.access_token == nil do
      set_errors!(conn, [
        error(token.other_params["error"], token.other_params["error_description"])
      ])
    else
      fetch_user(conn, token)
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc """
  Cleans up the private area of the connection used for passing the raw ID Austria response around during the callback.
  """
  def handle_cleanup!(conn) do
    conn
    |> put_private(:eid_token, nil)
    |> put_private(:eid_jwt, nil)
  end

  @doc """
  Fetches the uid field from the id token.
  """
  def uid(conn) do
    conn.private.eid_jwt.fields["urn:pvpgvat:oidc.bpk"]
  end

  @doc """
  Includes the credentials from the ID Austria token response.
  """
  def credentials(conn) do
    token = conn.private.eid_token
    scope_string = token.other_params["scope"] || ""
    scopes = String.split(scope_string, ",")

    %Credentials{
      token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: token.token_type,
      expires: !!token.expires_at,
      scopes: scopes
    }
  end

  @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  """
  def info(conn) do
    user = conn.private.eid_jwt.fields

    %Info{
      name: user["given_name"] <> " " <> user["family_name"],
      first_name: user["given_name"],
      last_name: user["family_name"],
      birthday: user["birthday"]
    }
  end

  @doc """
  Stores the raw information obtained from the ID Austria id_token.
  """
  def extra(conn) do
    %Extra{
      raw_info: conn.private.eid_jwt.fields
    }
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :eid_token, token)

    case JOSE.JWT.verify(UeberauthIdAustria.Config.verify_key(), token.other_params["id_token"]) do
      {true, jwt, _jws} -> put_private(conn, :eid_jwt, jwt)
      {false, _, _} -> set_errors!(conn, [error("invalid_signature", "Invalid Signature")])
    end
  end

  defp option(conn, key) do
    Keyword.get(options(conn) || [], key, Keyword.get(default_options(), key))
  end
end
