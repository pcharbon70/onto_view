import Config

# For development, we disable any cache and enable
# debugging and code reloading.
config :onto_view, OntoViewWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "YourSecretKeyBaseHere+YourSecretKeyBaseHere+YourSecretKeyBaseHere+YourSecretKeyBaseHere==",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:onto_view, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:onto_view, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :onto_view, OntoViewWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/onto_view_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :onto_view, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

config :onto_view, :ontology_loader, log_level: :debug

# Enable verbose RDF.ex logging
config :rdf,
  default_prefixes: %{
    owl: "http://www.w3.org/2002/07/owl#",
    rdf: "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    rdfs: "http://www.w3.org/2000/01/rdf-schema#",
    xsd: "http://www.w3.org/2001/XMLSchema#"
  }
