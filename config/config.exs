import Config

# Configure Phoenix
config :onto_view,
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :onto_view, OntoViewWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: OntoViewWeb.ErrorHTML, json: OntoViewWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: OntoView.PubSub,
  live_view: [signing_salt: "ontology_salt"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  onto_view: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  onto_view: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure MIME types for content negotiation
config :mime, :types, %{
  "text/turtle" => ["ttl"],
  "application/rdf+xml" => ["rdf"]
}

config :onto_view, :ontology_loader,
  # Default directory for ontology files
  default_ontology_dir: "priv/ontologies",

  # Max file size for non-streaming loads (10MB)
  max_file_size_bytes: 10_485_760,

  # Enable streaming for files larger than threshold (5MB)
  stream_threshold_bytes: 5_242_880,

  # Import chain resource limits (DoS protection)
  max_depth: 10,
  max_total_imports: 100,
  max_imports_per_ontology: 20,

  # Validation strictness
  # Warning only
  validate_ttl_extension: false,
  # Generate if missing
  require_base_iri: false,

  # Logging
  log_level: :info

# Environment-specific overrides
import_config "#{config_env()}.exs"
