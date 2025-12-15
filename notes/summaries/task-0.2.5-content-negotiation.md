# Task 0.2.5 — Content Negotiation Endpoint

**Branch:** `feature/phase-0.2.5-content-negotiation`
**Status:** ✅ Completed
**Date:** 2025-12-15

## Overview

Implemented W3C Linked Data best practices for content negotiation in the IRI resolution endpoint. The `/resolve` endpoint now inspects the `Accept` header and returns appropriate responses based on the requested content type.

## What Was Implemented

### 0.2.5.1 — Implement /resolve route accepting IRI query parameter ✅

**Already Complete** from Task 0.4.3 - Route exists at `GET /resolve?iri=<url-encoded-iri>`.

### 0.2.5.2 — Support content negotiation via Accept headers ✅

**Implementation:**
- Created `handle_content_negotiation/2` helper function
- Parses `Accept` header from HTTP request
- Routes to appropriate handler based on content type
- Supports: `text/html`, `application/json`, `text/turtle`, `application/rdf+xml`

**Code Location:** `lib/onto_view_web/controllers/resolve_controller.ex:70-87`

### 0.2.5.3 — Return 303 See Other redirects for successful resolutions ✅

**Implementation:**
- HTML redirects return HTTP 303 (See Other) status
- Turtle/RDF redirects return HTTP 303 with appropriate Content-Type header
- Follows W3C Linked Data best practices for IRI dereferencing

**Code Location:** `lib/onto_view_web/controllers/resolve_controller.ex:90-114`

### 0.2.5.4 — Handle text/html → documentation view redirect ✅

**Implementation:**
```elixir
defp handle_html_redirect(conn, result) do
  docs_url = ~p"/sets/#{result.set_id}/#{result.version}/docs"

  conn
  |> put_status(303)
  |> put_resp_header("location", docs_url)
  |> send_resp(303, "")
end
```

**Behavior:**
- Redirects to `/sets/:set_id/:version/docs` documentation view
- Returns HTTP 303 (See Other) status
- Default behavior when no Accept header or wildcard `*/*`

### 0.2.5.5 — Handle text/turtle → TTL export redirect ✅

**Implementation:**
```elixir
defp handle_turtle_redirect(conn, result) do
  ttl_url = "/sets/#{result.set_id}/#{result.version}/export.ttl"

  conn
  |> put_status(303)
  |> put_resp_header("content-type", "text/turtle; charset=utf-8")
  |> put_resp_header("location", ttl_url)
  |> send_resp(303, "")
end
```

**Behavior:**
- Redirects to `/sets/:set_id/:version/export.ttl` (placeholder for Phase 5)
- Also handles `application/rdf+xml` Accept header
- Returns HTTP 303 with `text/turtle` Content-Type header

### 0.2.5.6 — Handle application/json → JSON metadata response ✅

**Implementation:**
```elixir
defp handle_json_response(conn, result) do
  base_url = OntoViewWeb.Endpoint.url()

  json(conn, %{
    iri: result.iri,
    set_id: result.set_id,
    version: result.version,
    entity_type: result.entity_type,
    documentation_url: "#{base_url}/sets/#{result.set_id}/#{result.version}/docs",
    ttl_export_url: "#{base_url}/sets/#{result.set_id}/#{result.version}/export.ttl"
  })
end
```

**Behavior:**
- Returns JSON metadata about the resolved IRI
- Includes: IRI, set_id, version, entity_type, documentation_url, ttl_export_url
- Returns HTTP 200 with `application/json` Content-Type

## Files Created/Modified

**Modified (3 files):**
1. `lib/onto_view_web/controllers/resolve_controller.ex` - Added content negotiation logic
2. `lib/onto_view_web/router.ex` - Created `:content_negotiation` pipeline
3. `config/config.exs` - Registered custom MIME types

**Modified (1 file):**
4. `test/onto_view_web/controllers/resolve_controller_test.exs` - Added content negotiation tests

## Test Coverage

**Total Tests:** 9 tests, all passing ✅

**Error Cases (3 tests):**
- ✅ Redirects when IRI not found
- ✅ Redirects when iri parameter missing
- ✅ Accepts URL-encoded IRIs

**Content Negotiation (6 tests):**
- ✅ Accepts text/html Accept header
- ✅ Accepts application/json Accept header
- ✅ Accepts text/turtle Accept header
- ✅ Accepts application/rdf+xml Accept header
- ✅ Handles wildcard `*/*` Accept header
- ✅ Handles browser-like complex Accept headers

## Technical Highlights

### Content Negotiation Pipeline

Created custom Phoenix pipeline that accepts multiple content types:
```elixir
pipeline :content_negotiation do
  plug :accepts, ["html", "json", "ttl", "rdf"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_secure_browser_headers
  plug OntoViewWeb.Plugs.SetResolver
end
```

### MIME Type Registration

Registered custom MIME types in `config/config.exs`:
```elixir
config :mime, :types, %{
  "text/turtle" => ["ttl"],
  "application/rdf+xml" => ["rdf"]
}
```

### Content Type Priority

The implementation uses simple `String.contains?` matching with priority:
1. `application/json` - Returns JSON metadata
2. `text/turtle` or `application/rdf+xml` - Redirects to TTL export
3. Default (including `text/html`, `*/*`) - Redirects to HTML documentation

### W3C Linked Data Best Practices

Follows W3C recommendations for Linked Data publishing:
- HTTP 303 (See Other) redirects for resource dereferencing
- Content negotiation based on Accept headers
- Separate URIs for HTML (human-readable) and RDF (machine-readable) representations

## Integration Points

**With Task 0.2.4 (IRI Resolution):**
- ✅ Calls `OntologyHub.resolve_iri/1` to find IRI in loaded sets
- ✅ Uses returned `set_id`, `version`, and `entity_type` metadata

**With Task 0.4.3 (Route Structure):**
- ✅ Redirects to `/sets/:set_id/:version/docs` for HTML requests
- ✅ References `/sets/:set_id/:version/export.ttl` (placeholder for Phase 5)

**Future Phase 5 (Export):**
- TTL export endpoint `/sets/:set_id/:version/export.ttl` will be implemented
- Will provide actual Turtle serialization of the ontology set

## Example Usage

### HTML Documentation Request

```http
GET /resolve?iri=http%3A%2F%2Fexample.org%2Felixir%2Fcore%23Module HTTP/1.1
Accept: text/html

HTTP/1.1 303 See Other
Location: /sets/elixir/v1.17/docs
```

### JSON Metadata Request

```http
GET /resolve?iri=http%3A%2F%2Fexample.org%2Felixir%2Fcore%23Module HTTP/1.1
Accept: application/json

HTTP/1.1 200 OK
Content-Type: application/json

{
  "iri": "http://example.org/elixir/core#Module",
  "set_id": "elixir",
  "version": "v1.17",
  "entity_type": "class",
  "documentation_url": "http://localhost:4000/sets/elixir/v1.17/docs",
  "ttl_export_url": "http://localhost:4000/sets/elixir/v1.17/export.ttl"
}
```

### Turtle Export Request

```http
GET /resolve?iri=http%3A%2F%2Fexample.org%2Felixir%2Fcore%23Module HTTP/1.1
Accept: text/turtle

HTTP/1.1 303 See Other
Content-Type: text/turtle; charset=utf-8
Location: /sets/elixir/v1.17/export.ttl
```

## Limitations and Future Work

1. **TTL Export Endpoint** - Currently returns placeholder URL, actual export will be in Phase 5
2. **Entity-Specific URLs** - Currently redirects to docs landing, Phase 2 will add entity-specific routes
3. **Quality Values** - Accept header quality values (q=0.9) are not parsed, uses simple contains check
4. **Full Integration Tests** - Task 0.2.99 will add comprehensive end-to-end testing

## Compliance

✅ All subtask requirements met:
- [x] 0.2.5.1 — `/resolve` route accepting IRI query parameter
- [x] 0.2.5.2 — Support content negotiation via Accept headers
- [x] 0.2.5.3 — Return 303 See Other redirects
- [x] 0.2.5.4 — Handle text/html → documentation view redirect
- [x] 0.2.5.5 — Handle text/turtle → TTL export redirect
- [x] 0.2.5.6 — Handle application/json → JSON metadata response

✅ Code quality:
- All tests passing (9/9)
- Proper Phoenix conventions
- W3C Linked Data compliance
- Comprehensive error handling

## Conclusion

Task 0.2.5 (Content Negotiation Endpoint) is complete. The `/resolve` endpoint now implements W3C Linked Data best practices for content negotiation, supporting HTML documentation views, JSON metadata responses, and Turtle export redirects. The implementation provides a foundation for semantic web interoperability and will integrate with Phase 5 export functionality.

**Ready for integration testing in Task 0.2.99.**
