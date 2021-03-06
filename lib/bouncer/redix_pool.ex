defmodule Bouncer.RedixPool do
  @moduledoc """
  A library of functions used to create and use a Redis pool through Redix.
  """

  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    pool_opts = [
      name: {:local, :redix_poolboy},
      worker_module: Redix,
      size: Application.get_env(:bouncer, :pool_size, 10),
      max_overflow: Application.get_env(:bouncer, :pool_overflow, 5)
    ]

    children = [
      :poolboy.child_spec(
        :redix_poolboy,
        pool_opts,
        Application.get_env(:bouncer, :redis, [])
      )
    ]

    supervise(children, strategy: :one_for_one, name: __MODULE__)
  end

  def command(command) do
    :poolboy.transaction(:redix_poolboy, &Redix.command(&1, command))
  end

  def pipeline(commands) do
    :poolboy.transaction(:redix_poolboy, &Redix.pipeline(&1, commands))
  end
end
