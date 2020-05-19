# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :poker,
  ecto_repos: [Poker.Repo]

# Configures the endpoint
config :poker, PokerWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "1E3d8QMy5kbeBkJCgI674c2yz0rsDicPF6lfo+slLhUnLmeboCp+YIdHg/xeLWSf",
  render_errors: [view: PokerWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Poker.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [signing_salt: "obkFI3Zo"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
