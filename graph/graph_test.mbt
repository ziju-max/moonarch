///|
test "normalization sorts packages and deduplicates edges" {
  let edge = @graph.Edge::new(
    source="a/pkg",
    target="b/pkg",
    kind=@graph.Normal,
  )
  let graph = @graph.normalize(["b/pkg", "a/pkg"], [edge, edge])
  assert_eq(graph.packages(), ["a/pkg", "b/pkg"])
  assert_eq(graph.edges().length(), 1)
}

///|
test "normalization rejects an empty package name" {
  try {
    @graph.normalize([""], []) |> ignore
    fail("empty package name must be rejected")
  } catch {
    @graph.GraphError::EmptyPackageName => ()
    _ => fail("unexpected graph error")
  }
}

///|
test "normalization rejects path traversal package segments" {
  for package_name in ["acme/./app", "acme/../app", "../app"] {
    try {
      @graph.normalize([package_name], []) |> ignore
      fail("dot path segments must not enter the package graph")
    } catch {
      @graph.GraphError::InvalidPackageName(value) =>
        assert_eq(value, package_name)
      _ => fail("malformed package names must be rejected explicitly")
    }
  }
}

///|
test "normalization rejects dangling endpoints" {
  let edge = @graph.Edge::new(
    source="a/pkg",
    target="missing/pkg",
    kind=@graph.Normal,
  )
  try {
    @graph.normalize(["a/pkg"], [edge]) |> ignore
    fail("dangling endpoint must be rejected")
  } catch {
    @graph.GraphError::DanglingEdge(_, _) => ()
    _ => fail("unexpected graph error")
  }
}

///|
test "offline graph JSON preserves three edge kinds" {
  let graph = @graph.parse_offline_json(
    (
      #|{"schema_version":1,"packages":["a","b","c"],"edges":[
      #|  {"source":"a","target":"b","kind":"normal"},
      #|  {"source":"b","target":"c","kind":"test"},
      #|  {"source":"c","target":"a","kind":"wbtest"}
      #|]}
    ),
  )
  assert_true(graph.has_edge("a", "b", @graph.Normal))
  assert_true(graph.has_edge("b", "c", @graph.Test))
  assert_true(graph.has_edge("c", "a", @graph.Wbtest))
}

///|
test "offline graph JSON rejects unknown fields and dangling edges" {
  try {
    @graph.parse_offline_json(
      (
        #|{"schema_version":1,"packages":["a"],"edges":[],"extra":true}
      ),
    )
    |> ignore
    fail("unknown fields must be rejected")
  } catch {
    @graph.OfflineGraphError::UnknownField(path~) => assert_eq(path, "$.extra")
    _ => fail("expected offline graph error")
  }
  try {
    @graph.parse_offline_json(
      (
        #|{"schema_version":1,"packages":["a"],"edges":[{"source":"a","target":"b","kind":"normal"}]}
      ),
    )
    |> ignore
    fail("dangling endpoints must be rejected")
  } catch {
    @graph.OfflineGraphError::InvalidGraph => ()
    _ => fail("expected invalid graph error")
  }
}

///|
test "offline graph JSON rejects duplicate keys, versions, and edge kinds" {
  try {
    @graph.parse_offline_json(
      "{\"schema_version\":1,\"schema_version\":1,\"packages\":[],\"edges\":[]}",
    )
    |> ignore
    fail("duplicate keys must fail")
  } catch {
    @graph.OfflineGraphError::InvalidJson => ()
    _ => fail("expected invalid JSON")
  }
  try {
    @graph.parse_offline_json(
      "{\"schema_version\":2,\"packages\":[],\"edges\":[]}",
    )
    |> ignore
    fail("unknown graph schema version must fail")
  } catch {
    @graph.OfflineGraphError::UnsupportedVersion(2) => ()
    _ => fail("expected unsupported version")
  }
  try {
    @graph.parse_offline_json(
      "{\"schema_version\":1,\"packages\":[\"a\"],\"edges\":[{\"source\":\"a\",\"target\":\"a\",\"kind\":\"generated\"}]}",
    )
    |> ignore
    fail("unknown edge kind must fail")
  } catch {
    @graph.OfflineGraphError::InvalidEdgeKind("generated") => ()
    _ => fail("expected invalid edge kind")
  }
}

///|
test "offline graph decoder reports malformed root and edge fields" {
  try {
    @graph.parse_offline_json("[]") |> ignore
    fail("root must be an object")
  } catch {
    @graph.OfflineGraphError::InvalidShape("$") => ()
    _ => fail("expected invalid root shape")
  }
  try {
    @graph.parse_offline_json(
      "{\"schema_version\":1,\"packages\":[\"a\"],\"edges\":[{\"source\":\"a\",\"kind\":\"normal\"}]}",
    )
    |> ignore
    fail("edge target is required")
  } catch {
    @graph.OfflineGraphError::InvalidShape("$.edges[0].target") => ()
    _ => fail("expected missing target error")
  }
}

///|
test "test contexts include source edges and isolate test edge kinds" {
  assert_true(@graph.TestContext.allows(@graph.Normal))
  assert_true(@graph.TestContext.allows(@graph.Test))
  assert_false(@graph.TestContext.allows(@graph.Wbtest))
  assert_true(@graph.WbtestContext.allows(@graph.Normal))
  assert_true(@graph.WbtestContext.allows(@graph.Wbtest))
  assert_false(@graph.WbtestContext.allows(@graph.Test))
  assert_true(@graph.NormalContext.allows(@graph.Normal))
  assert_false(@graph.NormalContext.allows(@graph.Test))
}
