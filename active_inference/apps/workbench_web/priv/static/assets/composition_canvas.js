// Plan §5 + §12 Phase 7 + Lego-uplift Phase B — CompositionCanvas LiveView hook.
//
// Wraps litegraph.js (loaded globally via <script> in the root layout).
// The server is the authority on topology; this hook:
//   1. hydrates from the data-topology attribute on mount,
//   2. accepts HTML5 drag-and-drop from palette cards and pushes `add_node`
//      with {type, x, y} so the server appends the node and replies with
//      a fresh topology,
//   3. pushes `topology_changed` on every drag/connect/param edit
//      (debounced to 150ms),
//   4. pushes `select_node` when the user clicks a node on the canvas,
//   5. re-renders when the server replaces data-topology (server
//      validation produced a corrected topology).

window.CompositionCanvas = {
  mounted() {
    this.graph = new LiteGraph.LGraph();
    this.registerNodeTypes();

    this.canvasEl = document.createElement("canvas");
    this.canvasEl.style.width = "100%";
    this.canvasEl.style.height = "100%";
    this.canvasEl.width = this.el.clientWidth || 900;
    this.canvasEl.height = this.el.clientHeight || 520;
    this.el.appendChild(this.canvasEl);

    this.lcanvas = new LiteGraph.LGraphCanvas(this.canvasEl, this.graph);

    // Hydrate from data-topology
    this.lastServerJson = this.el.dataset.topology;
    this.hydrate(JSON.parse(this.lastServerJson));

    // Push to server on any change, debounced.
    this.graph.onAfterChange = () => this.schedulePush();
    this.graph.onNodeAdded = () => this.schedulePush();
    this.graph.onNodeRemoved = () => this.schedulePush();
    this.graph.onConnectionChange = () => this.schedulePush();

    // HTML5 drag-and-drop from palette onto canvas.
    this.el.addEventListener("dragover", (e) => {
      // Needed so `drop` fires.
      e.preventDefault();
      e.dataTransfer.dropEffect = "copy";
    });

    this.el.addEventListener("drop", (e) => {
      e.preventDefault();
      const nodeType = e.dataTransfer.getData("application/x-node-type");
      const archetypeId = e.dataTransfer.getData("application/x-archetype-id");
      if (!nodeType && !archetypeId) return;

      // Map client coords to canvas-local coords, accounting for the
      // litegraph pan/zoom.
      const rect = this.canvasEl.getBoundingClientRect();
      const canvasX = e.clientX - rect.left;
      const canvasY = e.clientY - rect.top;
      const worldXY = this.lcanvas.convertCanvasToOffset
        ? this.lcanvas.convertCanvasToOffset([canvasX, canvasY])
        : [canvasX, canvasY];

      this.pushEvent("add_node", {
        type: nodeType || null,
        archetype_id: archetypeId || null,
        x: Math.round(worldXY[0]),
        y: Math.round(worldXY[1])
      });
    });

    // Node selection → push select_node to the LiveView.
    this.lcanvas.onNodeSelected = (node) => {
      const id = node && node.properties && node.properties.__id;
      if (id) this.pushEvent("select_node", { id });
    };
    this.lcanvas.onNodeDeselected = () => {
      this.pushEvent("select_node", { id: null });
    };

    this.graph.start(); // enables render loop
  },

  updated() {
    // Only rehydrate if the server-side topology actually changed.
    const newJson = this.el.dataset.topology;
    if (newJson && newJson !== this.lastServerJson) {
      this.lastServerJson = newJson;
      this.hydrate(JSON.parse(newJson));
    }
  },

  destroyed() {
    this.graph && this.graph.stop();
  },

  registerNodeTypes() {
    // Fetch the authoritative node types from the server (embedded as
    // a data-attribute on the canvas host). Falls back to the baseline
    // POMDP set for compatibility with older server builds.
    const BASELINE = {
      bundle:    { out: { bundle: "bundle" } },
      archetype: { out: { topology: "topology" } },
      equation:  { out: { equation_id: "equation_id" } },
      perceive:  { in: { bundle: "bundle", obs: "obs" }, out: { beliefs: "belief" } },
      plan:      { in: { bundle: "bundle", beliefs: "belief" }, out: { policy_posterior: "policy_posterior", action: "action" } },
      act:       { in: { action: "action" }, out: { signal: "signal" } },
      likelihood_matrix:  { out: { A: "matrix_a" } },
      transition_matrix:  { out: { B: "matrix_b" } },
      preference_vector:  { out: { C: "vector_c" } },
      prior_vector:       { out: { D: "vector_d" } },
      bundle_assembler:   { in: { A: "matrix_a", B: "matrix_b", C: "vector_c", D: "vector_d" }, out: { bundle: "bundle" } },
      sophisticated_planner: { in: { bundle: "bundle", beliefs: "belief" }, out: { policy_posterior: "policy_posterior", action: "action" } },
      dirichlet_a_learner: { in: { bundle: "bundle", obs: "obs", beliefs: "belief" }, out: { bundle: "bundle" } },
      dirichlet_b_learner: { in: { bundle: "bundle", beliefs: "belief", action: "action" }, out: { bundle: "bundle" } },
      skill:               { in: { in: "any" }, out: { out: "any" } },
      workflow:            { in: { in: "any" }, out: { out: "any" } },
      epistemic_preference:{ in: { bundle: "bundle" }, out: { bundle: "bundle" } },
      meta_agent:          { in: { obs: "obs" }, out: { preference: "vector_c" } },
      sub_agent:           { in: { bundle: "bundle", preference: "vector_c", obs: "obs" }, out: { action: "action" } }
    };

    let NODE_TYPES;
    try {
      const fromServer = this.el.dataset.nodeTypes;
      NODE_TYPES = fromServer ? JSON.parse(fromServer) : BASELINE;
    } catch (_e) {
      NODE_TYPES = BASELINE;
    }

    Object.keys(NODE_TYPES).forEach((type) => {
      const spec = NODE_TYPES[type];

      function Ctor() {
        if (spec.in) {
          Object.entries(spec.in).forEach(([name, portType]) => this.addInput(name, portType));
        }
        if (spec.out) {
          Object.entries(spec.out).forEach(([name, portType]) => this.addOutput(name, portType));
        }
        this.properties = { params: {} };
      }

      Ctor.title = type;
      LiteGraph.registerNodeType(`worldmodels/${type}`, Ctor);
    });
  },

  hydrate(topology) {
    if (!topology || !Array.isArray(topology.nodes)) return;
    this.isHydrating = true;
    this.graph.clear();

    // Build id -> litegraph node map.
    const idMap = {};
    topology.nodes.forEach((n) => {
      const liteNode = LiteGraph.createNode(`worldmodels/${n.type}`);
      if (!liteNode) return;
      liteNode.title = `${n.type}`;
      liteNode.properties = { params: n.params || {}, __id: n.id };
      const pos = n.position || { x: 80, y: 80 };
      liteNode.pos = [pos.x, pos.y];
      this.graph.add(liteNode);
      idMap[n.id] = liteNode;
    });

    (topology.edges || []).forEach((e) => {
      const from = idMap[e.from_node];
      const to = idMap[e.to_node];
      if (!from || !to) return;
      const fromSlot = this.findSlot(from, "out", e.from_port);
      const toSlot = this.findSlot(to, "in", e.to_port);
      if (fromSlot >= 0 && toSlot >= 0) {
        from.connect(fromSlot, to, toSlot);
      }
    });

    this.isHydrating = false;
  },

  findSlot(node, dir, name) {
    const slots = dir === "out" ? node.outputs : node.inputs;
    if (!slots) return -1;
    return slots.findIndex((s) => s && s.name === name);
  },

  schedulePush() {
    if (this.isHydrating) return;
    clearTimeout(this._pushTimer);
    this._pushTimer = setTimeout(() => this.pushTopology(), 150);
  },

  pushTopology() {
    const topology = this.serialize();
    const json = JSON.stringify(topology);
    if (json === this.lastSentJson) return;
    this.lastSentJson = json;
    this.pushEvent("topology_changed", { topology });
  },

  serialize() {
    const nodes = this.graph._nodes.map((n) => ({
      id: (n.properties && n.properties.__id) || `n_${n.id}`,
      type: this.typeOf(n),
      params: (n.properties && n.properties.params) || {},
      position: { x: n.pos[0], y: n.pos[1] },
    }));

    const edges = [];
    this.graph._nodes.forEach((from) => {
      if (!from.outputs) return;
      from.outputs.forEach((outSlot, outIdx) => {
        const links = outSlot.links || [];
        links.forEach((linkId) => {
          const link = this.graph.links[linkId];
          if (!link) return;
          const to = this.graph.getNodeById(link.target_id);
          if (!to) return;
          edges.push({
            from_node: (from.properties && from.properties.__id) || `n_${from.id}`,
            from_port: outSlot.name,
            to_node: (to.properties && to.properties.__id) || `n_${to.id}`,
            to_port: to.inputs[link.target_slot].name,
          });
        });
      });
    });

    return { nodes, edges };
  },

  typeOf(node) {
    // Node.type is "worldmodels/<kind>"; strip the prefix.
    const t = node.type || "";
    return t.startsWith("worldmodels/") ? t.slice("worldmodels/".length) : t;
  },
};
