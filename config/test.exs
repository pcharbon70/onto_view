import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :onto_view, OntoViewWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "TestSecretKeyBaseHere+TestSecretKeyBaseHere+TestSecretKeyBaseHere+TestSecretKeyBaseHere",
  server: false

config :onto_view, :ontology_loader,
  log_level: :warning,
  default_ontology_dir: "test/support/fixtures/ontologies"

# Silence logs during tests
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
