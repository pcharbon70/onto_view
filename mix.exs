defmodule OntoView.MixProject do
  use Mix.Project

  def project do
    [
      app: :onto_view,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:web_ui, path: "/home/ducky/code/web_ui"},
      {:triple_store, path: "../triple_store"},
      {:rdf, "~> 2.1"}
    ]
  end
end
