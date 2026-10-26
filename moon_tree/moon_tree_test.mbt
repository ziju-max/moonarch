///|
test "Moon tree data maps package nodes and edge kinds" {
  let graph = @moon_tree.parse_moon_tree_json(
    (
      #|{
      #|  "version": 3,
      #|  "status": "success",
      #|  "nodes": [
      #|    {"module": "demo/workspace", "rel": "app"},
      #|    {"module": "demo/workspace", "rel": "domain"},
      #|    {"module": "demo/workspace", "rel": "storage"}
      #|  ],
      #|  "edges": [
      #|    {"from": 0, "to": 1, "kinds": ["source"]},
      #|    {"from": 1, "to": 2, "kinds": ["source", "blackbox-test"]}
      #|  ]
      #|}
    ),
  )
  assert_true(
    graph.has_edge("demo/workspace/app", "demo/workspace/domain", @graph.Normal),
  )
  assert_true(
    graph.has_edge(
      "demo/workspace/domain",
      "demo/workspace/storage",
      @graph.Normal,
    ),
  )
  assert_true(
    graph.has_edge(
      "demo/workspace/domain",
      "demo/workspace/storage",
      @graph.Test,
    ),
  )
}

///|
test "Moon tree rejects unsupported schema versions" {
  try {
    @moon_tree.parse_moon_tree_json(
      "{\"version\":99,\"status\":\"success\",\"nodes\":[],\"edges\":[]}",
    )
    |> ignore
    fail("unsupported version must be rejected")
  } catch {
    @moon_tree.MoonTreeError::UnsupportedVersion(99) => ()
    _ => fail("unexpected moon tree error")
  }
}
