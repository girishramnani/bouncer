defmodule EmailVerificationTest do
  use ExUnit.Case

  alias Plug.Conn
  alias Bouncer.RedixPool
  alias Bouncer.Adapters.Redis
  alias Bouncer.MockEndpoint
  alias Bouncer.EmailVerification
  alias Bouncer.Token

  doctest Bouncer.Session

  setup do
    RedixPool.command(~w(FLUSHALL))
    {:ok, conn: %Conn{} |> Conn.put_private(:phoenix_endpoint, MockEndpoint)}
  end

  test "email verification token is generated", %{conn: conn} do
    user = %{"id" => 1}
    {:ok, token} = EmailVerification.generate(conn, user)

    assert {:ok, [token]} === Redis.all(1)
    assert {:ok, user} === Redis.get(token)
  end

  test "email verification token is regenerated", %{conn: conn} do
    user = %{"id" => 2}
    {:ok, test_token} = EmailVerification.generate(conn, user, 86400)
    :timer.sleep(1)
    {:ok, new_token} = EmailVerification.regenerate(conn, user, 86400)

    assert {:error, nil} === Redis.get(test_token)
    assert {:ok, user} === Redis.get(new_token)
    assert {:ok, [new_token]} === Redis.all(user["id"])
  end

  test "valid email verification token is verified", %{conn: conn} do
    user = %{"id" => 1}
    {:ok, token} = EmailVerification.generate(conn, user, 86400)
    assert {:ok, user} === EmailVerification.verify(conn, token)
  end

  test "invalid email verification token is not verified", %{conn: conn} do
    {:ok, token} = Token.generate(conn, "test", %{"id" => 1}, 86400)
    assert {:error, "Invalid token"} === EmailVerification.verify(conn, token)
  end

  test "email verification token not verified when not stored", %{conn: conn} do
    token = Phoenix.Token.sign(conn, "email", 1)
    assert {:error, nil} === EmailVerification.verify(conn, token)
  end
end
