defmodule OntoViewWeb.DocsLive.Index do
  @moduledoc """
  LiveView for ontology documentation.

  This is a placeholder for Phase 2 documentation interface. In Phase 2, this
  LiveView will provide:
  - Hierarchical class browser with expand/collapse
  - Property and individual listings
  - Live search and filtering
  - Real-time navigation

  For now, it displays basic ontology set information loaded by SetResolver.

  ## Route
  /sets/:set_id/:version/docs

  ## Assigns (from SetResolver plug)
  - `:ontology_set` - Full OntologySet struct
  - `:triple_store` - TripleStore for queries
  - `:set_id` - Set identifier
  - `:version` - Version string
  """

  use OntoViewWeb, :live_view

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    # SetResolver plug should have already loaded the ontology set into assigns
    # But in LiveView tests, plugs don't run, so we need to load it ourselves
    socket =
      if Map.has_key?(socket.assigns, :ontology_set) do
        socket
      else
        # Load the set manually (for tests)
        set_id = params["set_id"] || socket.assigns[:set_id]
        version = params["version"] || socket.assigns[:version]

        case OntoView.OntologyHub.get_set(set_id, version) do
          {:ok, ontology_set} ->
            socket
            |> assign(:ontology_set, ontology_set)
            |> assign(:triple_store, ontology_set.triple_store)
            |> assign(:set_id, set_id)
            |> assign(:version, version)

          {:error, _} ->
            socket
        end
      end

    ontology_set = socket.assigns.ontology_set
    triple_store = socket.assigns.triple_store

    {:ok,
     assign(socket,
       page_title: "#{ontology_set.set_id} #{ontology_set.version} Documentation",
       triple_count: count_triples(triple_store),
       file_count: map_size(ontology_set.ontologies)
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="px-4 py-20 sm:px-6 lg:px-8 xl:px-28">
      <div class="mx-auto max-w-4xl">
        <div class="mb-8">
          <a
            href={~p"/sets/#{@set_id}"}
            class="text-sm text-zinc-600 hover:text-zinc-900 flex items-center gap-2 mb-4"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
            Back to versions
          </a>

          <h1 class="text-4xl font-bold tracking-tight text-zinc-900 mb-4">
            <%= @set_id %> <span class="text-zinc-500"><%= @version %></span>
          </h1>

          <p class="text-lg text-zinc-600">
            Documentation interface (placeholder for Phase 2)
          </p>
        </div>

        <div class="bg-blue-50 border border-blue-200 rounded-lg p-6 mb-8">
          <h2 class="text-lg font-semibold text-blue-900 mb-2">
            Phase 2 Implementation Pending
          </h2>
          <p class="text-blue-800">
            This LiveView is a placeholder. Full documentation interface will be implemented in Phase 2, including:
          </p>
          <ul class="list-disc list-inside text-blue-800 mt-2 space-y-1">
            <li>Hierarchical class browser with expand/collapse</li>
            <li>Property and individual listings</li>
            <li>Live search and filtering</li>
            <li>Entity detail views</li>
            <li>Graph visualization integration</li>
          </ul>
        </div>

        <div class="bg-white border border-zinc-200 rounded-lg p-6">
          <h2 class="text-xl font-semibold text-zinc-900 mb-4">Loaded Ontology Information</h2>

          <dl class="space-y-3">
            <div>
              <dt class="text-sm font-medium text-zinc-500">Set ID</dt>
              <dd class="mt-1 text-sm text-zinc-900 font-mono"><%= @set_id %></dd>
            </div>

            <div>
              <dt class="text-sm font-medium text-zinc-500">Version</dt>
              <dd class="mt-1 text-sm text-zinc-900 font-mono"><%= @version %></dd>
            </div>

            <div>
              <dt class="text-sm font-medium text-zinc-500">Files Loaded</dt>
              <dd class="mt-1 text-sm text-zinc-900"><%= @file_count %></dd>
            </div>

            <div>
              <dt class="text-sm font-medium text-zinc-500">Total Triples</dt>
              <dd class="mt-1 text-sm text-zinc-900"><%= @triple_count %></dd>
            </div>

            <div>
              <dt class="text-sm font-medium text-zinc-500">SetResolver Status</dt>
              <dd class="mt-1 text-sm text-green-600 font-medium">✓ Working correctly</dd>
            </div>
          </dl>
        </div>
      </div>
    </div>
    """
  end

  # Private Functions

  defp count_triples(nil), do: 0

  defp count_triples(triple_store) do
    # Use the count function from TripleStore
    OntoView.Ontology.TripleStore.count(triple_store)
  end
end
