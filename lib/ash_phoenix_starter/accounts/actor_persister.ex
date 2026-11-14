defmodule AshPhoenixStarter.Accounts.ObanActorPersister do
  @moduledoc """
  Persists and retrieves Ash actors for background Oban jobs.

  Serializes known actor structs (such as `User`) into JSON-safe maps for Oban's
  `args` field, and reloads them when the worker executes.
  """
  use AshOban.ActorPersister

  alias AshPhoenixStarter.Accounts
  alias AshPhoenixStarter.Accounts.User

  @doc """
  Serializes an actor into a map suitable for Oban job arguments.
  """
  @impl AshOban.ActorPersister
  def store(%User{id: id}), do: %{"type" => "user", "id" => id}
  def store(nil), do: nil

  @doc """
  Looks up the persisted actor from Oban job arguments.

  Passes `authorize?: false` to bypass policies when hydrating the actor itself,
  and `not_found_error?: false` so deleted users resolve cleanly to `{:ok, nil}`
  rather than crashing the job with an unhandled exception.
  """
  @impl AshOban.ActorPersister
  def lookup(%{"type" => "user", "id" => id}) when is_binary(id) do
    Accounts.get_user_by_id(id, authorize?: false, not_found_error?: false)
  end

  def lookup(nil), do: {:ok, nil}
  def lookup(_other), do: {:error, :invalid_actor_payload}
end
