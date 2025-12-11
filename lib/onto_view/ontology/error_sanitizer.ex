defmodule OntoView.Ontology.ErrorSanitizer do
  @moduledoc """
  Sanitizes error messages to prevent information disclosure.

  This module ensures that sensitive file system paths and other internal
  details are not exposed in error messages returned to users, while still
  maintaining detailed logging for debugging purposes.

  ## Security Rationale

  Error messages that expose file paths can reveal:
  - Directory structure and organization
  - Usernames in home directories
  - Deployment paths and configuration
  - Existence of files and directories

  This module sanitizes errors at the boundary between internal processing
  and external responses, ensuring security without losing debugging capability.
  """

  @doc """
  Sanitizes an error tuple by removing or redacting sensitive information.

  File paths are replaced with generic placeholders while preserving error types
  and other non-sensitive context.

  ## Examples

      iex> alias OntoView.Ontology.ErrorSanitizer
      iex> ErrorSanitizer.sanitize_error({:error, :file_not_found})
      {:error, :file_not_found}

      iex> alias OntoView.Ontology.ErrorSanitizer
      iex> ErrorSanitizer.sanitize_error({:error, {:unauthorized_path, "File /secret/path outside allowed"}})
      {:error, {:unauthorized_path, "File path outside allowed directory"}}

      iex> alias OntoView.Ontology.ErrorSanitizer
      iex> ErrorSanitizer.sanitize_error({:ok, %{data: "test"}})
      {:ok, %{data: "test"}}
  """
  def sanitize_error({:error, reason}) do
    {:error, sanitize_reason(reason)}
  end

  def sanitize_error({:ok, _result} = success) do
    # Success cases don't need sanitization
    success
  end

  def sanitize_error(other) do
    # Pass through anything else unchanged
    other
  end

  @doc """
  Sanitizes just the error reason, without the tuple wrapper.

  Useful for internal error handling where the error type needs
  to be preserved but sensitive details removed.
  """
  def sanitize_reason(reason) when is_atom(reason) do
    # Simple atoms are safe
    reason
  end

  def sanitize_reason({:file_too_large, message}) when is_binary(message) do
    # Keep the limit info but remove any paths
    sanitized = sanitize_message(message)
    {:file_too_large, sanitized}
  end

  def sanitize_reason({:unauthorized_path, message}) when is_binary(message) do
    # Remove specific paths, keep general message
    {:unauthorized_path, "File path outside allowed directory"}
  end

  def sanitize_reason({:symlink_detected, _message}) do
    # Generic message, no path exposure
    {:symlink_detected, "Symlink detected - symlinks are not allowed"}
  end

  def sanitize_reason({:not_a_file, _message}) do
    # Generic message
    {:not_a_file, "Path is not a regular file"}
  end

  def sanitize_reason({:io_error, message}) when is_binary(message) do
    # Keep parser errors but sanitize any embedded paths
    sanitized = sanitize_message(message)
    {:io_error, sanitized}
  end

  def sanitize_reason({:parse_error, details}) do
    # Preserve parse error details but sanitize paths
    sanitized_details = sanitize_parse_error_details(details)
    {:parse_error, sanitized_details}
  end

  def sanitize_reason({:iri_not_resolved, iri}) when is_binary(iri) do
    # IRIs are generally safe to expose (they're from ontology content)
    # but sanitize if they look like file paths
    if looks_like_file_path?(iri) do
      {:iri_not_resolved, "IRI could not be resolved"}
    else
      {:iri_not_resolved, iri}
    end
  end

  def sanitize_reason({:circular_dependency, trace}) when is_map(trace) do
    # Cycle traces contain IRIs (ontology content) not file paths
    # These are safe to expose as they help users fix ontology issues
    {:circular_dependency, trace}
  end

  def sanitize_reason({:max_depth_exceeded, limit}) do
    # No sensitive info
    {:max_depth_exceeded, limit}
  end

  def sanitize_reason({:max_total_imports_exceeded, actual, limit}) do
    # No sensitive info
    {:max_total_imports_exceeded, actual, limit}
  end

  def sanitize_reason({:max_imports_per_ontology_exceeded, iri, count, limit}) do
    # IRI is ontology content, not a file path
    {:max_imports_per_ontology_exceeded, iri, count, limit}
  end

  def sanitize_reason(reason) when is_binary(reason) do
    # Generic string error - sanitize any paths
    sanitize_message(reason)
  end

  def sanitize_reason(reason) do
    # Unknown error format - pass through
    # Could log a warning that we encountered an unsanitized error type
    reason
  end

  # Private helpers

  defp sanitize_message(message) when is_binary(message) do
    message
    |> remove_absolute_paths()
    |> remove_home_directory_paths()
    |> remove_relative_paths()
  end

  defp remove_absolute_paths(message) do
    # Replace absolute Unix paths (starting with /)
    String.replace(message, ~r{/[a-zA-Z0-9_\-./]+}, "[path]")
  end

  defp remove_home_directory_paths(message) do
    # Replace home directory references
    String.replace(message, ~r{~[a-zA-Z0-9_\-./]*}, "[path]")
  end

  defp remove_relative_paths(message) do
    # Replace relative paths that look suspicious (../../../etc)
    String.replace(message, ~r{\.\./[a-zA-Z0-9_\-./]+}, "[path]")
  end

  defp sanitize_parse_error_details(details) when is_binary(details) do
    sanitize_message(details)
  end

  defp sanitize_parse_error_details(details) when is_map(details) do
    Map.new(details, fn {k, v} ->
      {k, if(is_binary(v), do: sanitize_message(v), else: v)}
    end)
  end

  defp sanitize_parse_error_details(details) do
    details
  end

  defp looks_like_file_path?(string) do
    String.starts_with?(string, "/") or
      String.starts_with?(string, "~") or
      String.starts_with?(string, "../") or
      String.starts_with?(string, "./") or
      String.contains?(string, "\\")  # Windows paths
  end
end
