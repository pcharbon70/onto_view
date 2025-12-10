import Config

config :onto_view, :ontology_loader,
  log_level: :warning,
  default_ontology_dir: "test/support/fixtures/ontologies"

# Silence logs during tests
config :logger, level: :warning
