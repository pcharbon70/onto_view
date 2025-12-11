import Config

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
