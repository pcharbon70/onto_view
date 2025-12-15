**Integrating a 3D Ontology Graph Viewer in Elixir (Phoenix LiveView)**

**Graph Data Structure for 3D Force Graph**

The **3D Force-Directed Graph** library expects the graph data as a JSON object with a list of nodes and a list of links. Each node should have a unique identifier (by default an id field), and each link should reference the source and target node ids. For example, the input JSON format is as follows:

{

"nodes": \[

{ "id": "id1", "name": "name1", "val": 1 },

{ "id": "id2", "name": "name2", "val": 10 },

…

\],

"links": \[

{ "source": "id1", "target": "id2", "name": "relatedTo" },

…

\]

}

Here, each node object has an **id** (used as the key for links) and can include additional attributes like **name** (display label) or **val** (numeric value to influence node size). Each link object uses **source** and **target** keys to point to the connected node ids, and can include a **name** or type to label the relationship. The 3D Force Graph library uses these fields by default (configurable via nodeId, linkSource, linkTarget options which default to "id", "source", "target" respectively). This means if your node objects have an id field, and links use source/target with those ids, the library will automatically connect them.

In the context of an OWL ontology, **we will represent each OWL individual as a node**, and each OWL object property assertion between two individuals as a link. For example, if the ontology has individuals :John and :Mary with a relationship :hasWife, in Turtle it might be described as a triple :John :hasWife :Mary .[w3.org](https://www.w3.org/2007/OWL/wiki/Primer#:~:text=match%20at%20L4653%20%3AJohn%20,%3AJohn%20%20owl%3AdifferentFrom%C2%A0%3ABill). In our graph JSON, we would create a node for John and Mary, and a link { "source": "John", "target": "Mary", "name": "hasWife" } to represent that relationship. By including the property name in the link's name field, we can later configure the graph to show it as a label on the connecting line (the library's linkLabel defaults to use the name field for tooltips or text on links). The result is that all **individuals** become nodes in the 3D force graph, and **relationships** (object properties between individuals) become edges connecting those nodes, effectively visualizing the knowledge graph of the ontology.

**Parsing OWL (.TTL) Files and Building the Graph Data**

To generate this JSON, we need to extract individuals and their relationships from the OWL Turtle files. We can achieve this using Elixir's RDF libraries. For example, the RDF.ex library provides Turtle parsing support. We can read a Turtle file into an in-memory RDF graph with a one-liner like:

graph = RDF.Turtle.read_file!("/path/to/ontology.ttl")

This uses RDF.Turtle.read_file! to deserialize the TTL content into a RDF.Graph structure. Once we have the RDF graph, we will perform the following steps to build our nodes and links data:

- **Identify Individuals:** In OWL, individuals are typically those resources that are instances of classes or explicitly declared as owl:NamedIndividual. For example, the ontology might contain declarations like :John rdf:type owl:NamedIndividual . and class assertions like :John rdf:type :Person .. We can filter the RDF graph's triples to collect all subjects that are individuals. This can be done by finding all subjects that have an RDF type which is an OWL class or owl:NamedIndividual. (If using SPARQL via the SPARQL.ex library, one could run a query to select all ?ind where ?ind rdf:type owl:NamedIndividual or ?ind rdf:type ?class with ?class rdf:type owl:Class.) For simplicity, we might also infer that any resource appearing as the subject of an object property assertion is an individual.
- **Identify Relationships (Object Properties):** Next, from the RDF graph we gather all triples that represent relationships between individuals. In OWL, object properties relate individuals to other individuals (whereas datatype properties relate individuals to literal values). We will filter triples of the form **(subject, predicate, object)** where both subject and object are identified as individuals (and ignore triples where the object is a literal or where the predicate is rdf:type). Each such triple corresponds to an edge in our graph. For example, a triple like :John :hasWife :Mary becomes a relationship linking John → Mary. We also capture the predicate (e.g. hasWife) as the type/name of the link.
- **Construct Nodes:** For each individual collected in step 1, create a node entry. The id for each node should be a unique identifier for that individual. In many cases, using the individual's IRI (or a simplified form of it) as the id is convenient. For readability, you might use the IRI's fragment or a label. For instance, an individual &lt;<http://example.com#Alice>&gt; could be represented with "id": "Alice" (assuming names are unique) and perhaps a separate "label": "Alice" if needed. You can also include other node attributes - for example, you might set "group" or "category" to the OWL class the individual belongs to, which can be used to color-code nodes by type (using the library's nodeAutoColorBy feature) or set a "val" based on some importance metric. At minimum, each node needs an id (and you can use name for the displayed label; by default the library will show name on hover for nodes).
- **Construct Links:** For each relationship triple from step 2, create a link entry with "source" equal to the subject's id and "target" equal to the object's id. Include a "name" field for the predicate (relationship type) - this will allow the 3D graph to display the property name on the link (for example, on hover or as text along the link if enabled). If the ontology defines many different relationship types, we could also use link colors to distinguish them (for instance, setting a "type" attribute and using linkAutoColorBy('type') to automatically color-code links by relationship type). Each link thus represents an OWL object property assertion between two individuals.
- **Serialize to JSON:** Finally, package the nodes and links into a JSON structure. In Elixir, you can use a library like Jason to encode the %{nodes: \[...\], links: \[...\]} map into a JSON string. This JSON will be sent to the front-end for visualization. (Alternatively, you could feed the data directly as a JavaScript object, but JSON is convenient for LiveView or API transmission.)

By following these steps, we transform the OWL ontology data into the **node-link format** required by the 3D Force Graph. The graph data structure effectively becomes a lightweight representation of the ontology's individual-to-individual relationships. For example, if our TTL defines individuals and an object property between them, such as:

:John rdf:type owl:NamedIndividual ;

rdf:type :Person ;

:hasWife :Mary .

:Mary rdf:type owl:NamedIndividual, :Person .

This would yield two node entries (John, Mary) and one link entry (John --hasWife--> Mary) in the JSON. We skip triples like :John rdf:type :Person for the visualization (since class membership could be shown via color or omitted for clarity), focusing on the inter-individual links.

**Integrating the 3D Graph into a Phoenix (LiveView) App**

With the data prepared, the next step is to **embed the 3D force graph visualization in our Elixir web application**. We are using Elixir 1.19, and likely Phoenix LiveView for real-time interactivity. Phoenix LiveView allows us to seamlessly integrate custom JavaScript when needed via **hooks**, and to scope JS to specific parts of the application. The goal is to use the 3D Force Graph library on the client-side to render the graph, while leveraging LiveView to manage data and events.

**Including the 3D Force Graph library:** We have two main options to include the JavaScript library in a Phoenix project: (a) install it via npm and bundle it with the asset build, or (b) load it from a CDN on the specific page where it's needed. Given that this 3D graph is a specialized feature (and to honor the "scope system" idea of keeping JS close to where it's used), the CDN approach is convenient. We can import the script in the page that needs it, avoiding bloating the global bundle with rarely-used code. The library's docs show that we can simply include:

&lt;script src="//cdn.jsdelivr.net/npm/3d-force-graph"&gt;&lt;/script&gt;

to load the UMD bundle of the ForceGraph3D component. You might place this script tag in the LiveView template that renders the graph, or in the layout with a conditional so it only appears for the ontology graph page. (Another modern approach is to use an ES module import in a &lt;script type="module"&gt; in that template, which could import ForceGraph3D from a CDN like Skypack/JSDelivr - similar to how one might include a copy-to-clipboard library only on specific pages.) Ensuring the script is loaded on that page means the ForceGraph3D constructor will be available globally when we need to initialize the graph.

**Mounting the graph with LiveView Hooks:** Phoenix LiveView provides _hooks_ to run custom JS code when specific DOM elements are added or updated. We will use a hook to initialize and control the 3D force graph. First, in the LiveView template (HEEx), we render a container element for the graph and attach a hook identifier. For example, in the template (say graph_live.html.heex):

<div id="ontology-graph" phx-hook="ForceGraph"

data-graph={@graph_json}>

&lt;!-- The 3D graph will render inside this div --&gt;

&lt;/div&gt;

Here, @graph_json is an assign containing the JSON string of our graph data (we set this assign in the LiveView after parsing the TTL). We pass it via a data-graph attribute on the div. The phx-hook="ForceGraph" attribute tells LiveView to invoke our custom hook named "ForceGraph" for this element.

Next, we define the hook in our JavaScript. In your app's asset JS (e.g., assets/js/hooks/force_graph.js or simply in app.js), you register a Hooks object, for example:

let Hooks = {}

Hooks.ForceGraph = {

mounted() {

// Parse the graph data from the data attribute

const graphData = JSON.parse(this.el.getAttribute("data-graph"));

// Initialize the 3D Force Graph on this element

this.graph = ForceGraph3D()(this.el)

.graphData(graphData)

.nodeLabel('name') // show the node's name on hover

.linkLabel('name') // show link type on hover (or always, if configured)

.backgroundColor('#000000'); // example: set background

// (Optional) configure additional behaviors, e.g., auto-zoom to fit:

this.graph.zoomToFit(500);

// (Optional) handle interactions, e.g., on node click, push an event or highlight:

this.graph.onNodeClick(node => {

// For example, send an event to LiveView with the clicked node ID

this.pushEvent("node_clicked", { id: node.id });

// Or client-side highlight: focus camera on the node, etc.

this.graph.cameraPosition({ x: node.x, y: node.y, z: node.z \* 1.3 }, node, 1000);

});

},

updated() {

// If @graph_json is updated (e.g., new data), update the graph

const newData = JSON.parse(this.el.getAttribute("data-graph"));

this.graph.graphData(newData);

}

}

In the above hook:

- **mounted()** runs when the element is first added to the DOM. We retrieve the JSON from the data-graph attribute and call ForceGraph3D()(this.el) to create a new 3D graph in our container element, then chain .graphData(graphData) to load our nodes and links. We also set some optional configurations: for instance, we ensure the node labels use the name field and link labels use name (so that hovering or zooming close will show the relationship names). We could also customize node size or colors here (e.g., nodeAutoColorBy('group') if we provided a group), or background color, etc.
- We demonstrate how to handle an interactive event: using .onNodeClick() we register a callback for when a node is clicked. The library will pass us the node object; in response we call this.pushEvent to send a message to the LiveView (so the server can, for example, display details about that node in a sidebar). We also optionally adjust the camera to focus on the clicked node as a visual feedback. The library supports other callbacks like onNodeHover, onLinkClick, etc., which we could use to enhance interactivity (for instance, highlighting connected nodes on hover).
- **updated()** runs if the LiveView DOM is patched and the element is still present (e.g., if we assign a new @graph_json). In such case, we parse the new data and call this.graph.graphData(newData) to update the graph. The 3D Force Graph supports dynamic updates; calling .graphData() again will re-render with the new data (keeping existing node objects if ids match, or adding/removing nodes as needed). This means if the ontology data changes (perhaps the user loaded a different TTL or added an individual), we can push a new assign and the hook will efficiently update the visualization without full reload.

Finally, we need to **register the hook** so Phoenix knows about it. In assets/js/app.js, ensure you import the hooks and add them to the LiveSocket:

import Hooks from "./hooks/force_graph"

...

let liveSocket = new LiveSocket("/live", Socket, {

hooks: Hooks,

params: { \_csrf_token: csrfToken }

});

...

liveSocket.connect();

Now, when the LiveView mounts the &lt;div phx-hook="ForceGraph"&gt;, our hook's mounted() will execute and render the graph. The heavy lifting (physics simulation, 3D rendering) happens client-side in the browser via Three.js, so it's quite efficient to handle even a few thousand nodes as the library's example shows.

_Figure 1: Example of a force-directed 3D graph visualization (rendered by the 3D Force Graph library). Nodes (spheres) represent entities/individuals and links (lines) represent relationships. The library uses a physics engine (d3-force-3d or ngraph) to layout the graph in a 3D space, and it supports interactive exploration - you can rotate, zoom, and even click on nodes/links to trigger custom behaviors._

**Additional Considerations for an Ontological Viewer**

Integrating the 3D force graph with Phoenix LiveView as described above utilizes the suggested patterns (colocating JavaScript with the LiveView component and using _JS hooks_ for interoperability) to achieve the end goal: an interactive ontology graph explorer. This approach keeps the JavaScript **scoped** to the relevant page/component (we only load and run the graph code where needed), and leverages LiveView's real-time capabilities for any dynamic updates or server-side interactions. A few final points to consider:

- **Ontology Size & Performance:** If the OWL dataset is large (thousands of individuals and many links), the 3D visualization can become cluttered or heavy. The library can handle a few thousand elements (there's an example with ~4k nodes), but you might want to implement techniques like filtering or clustering. For instance, you could start by visualizing certain subsets of the ontology (specific classes or relationships) and allow the user to expand a node to reveal more connections (this could be done by listening for node clicks and then loading that node's neighborhood on demand).
- **Visual Encoding:** Since this is an ontological view, it might make sense to use visual cues to denote ontology-specific information. You can use **node colors or sizes** to indicate different classes or key individuals (using nodeAutoColorBy or setting node color attributes before passing data). Likewise, you can style links differently based on property type (e.g., dashed lines for a certain property, or arrows for directional relationships). The 3D Force Graph supports directional arrows on links and other customizations (for example, .linkDirectionalArrowLength(…); .linkDirectionalParticleSpeed(…); etc., which could illustrate flow or hierarchy). These enhancements can make the ontology graph more informative.
- **User Interaction:** The explorer can be made interactive beyond just rotation/zoom. We already discussed using onNodeClick to show details or focus on a node. We could also implement search (highlight a node by id or name), or use LiveView events to update the graph. For example, if a user selects a particular class from a menu, the server could filter the graph data to only individuals of that class and send a smaller graph JSON to the client (triggering the hook's updated() to update the visualization). The **incremental update** capability of the library means we can smoothly add or remove nodes: it's possible to send **partial updates** instead of full reloads if needed, though the simplest method is just sending a new full dataset for moderate sizes.
- **Validation of Data:** When converting OWL to graph form, ensure that the individual IDs are unique and consistent. If the ontology uses full URIs, you might want to slugify or shorten them for use as node ids but maintain a mapping for display. Additionally, some ontologies might have anonymous individuals or blank nodes - those might need special handling (e.g. skipping or assigning a generated id).

In summary, using Phoenix LiveView with carefully scoped JavaScript hooks provides a robust way to integrate the **3D Force Graph** library into an Elixir application. We parse the OWL TTL files into an internal representation, transform that into the graph JSON format expected by the 3D force-directed graph component, and then render it in the browser. This achieves a rich, interactive **knowledge graph explorer** for the ontology's individuals and their relationships, using modern webgl-based visualization within our Elixir/Phoenix framework. By following these steps and patterns, we ensure the implementation remains maintainable (most logic in Elixir, with JS only where needed) and that the end goal - a dynamic 3D visualization of the ontology - is successfully realized.
