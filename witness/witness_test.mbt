///|
test "test context paths include normal and test edges" {
  let graph = @graph.normalize(["a", "b", "c"], [
    @graph.Edge::new(source="a", target="b", kind=@graph.Normal),
    @graph.Edge::new(source="b", target="c", kind=@graph.Test),
  ])
  let path = @witness.find_path(graph, "a", "c", @graph.TestContext)
  assert_true(path is Some(_))
  assert_true(
    @witness.path_contains_required_kind(path.unwrap(), @graph.TestContext),
  )
  assert_true(@witness.find_path(graph, "a", "c", @graph.NormalContext) is None)
  assert_true(@witness.find_path(graph, "a", "b", @graph.TestContext) is None)
}

///|
test "wbtest context excludes test-only edges" {
  let graph = @graph.normalize(["a", "b", "c"], [
    @graph.Edge::new(source="a", target="b", kind=@graph.Normal),
    @graph.Edge::new(source="b", target="c", kind=@graph.Test),
  ])
  assert_true(@witness.find_path(graph, "a", "c", @graph.WbtestContext) is None)
}

///|
test "wbtest paths require a whitebox edge and exclude blackbox-only paths" {
  let graph = @graph.normalize(["a", "b", "c", "d"], [
    @graph.Edge::new(source="a", target="b", kind=@graph.Normal),
    @graph.Edge::new(source="b", target="c", kind=@graph.Wbtest),
    @graph.Edge::new(source="c", target="d", kind=@graph.Test),
  ])
  let path = @witness.find_path(graph, "a", "c", @graph.WbtestContext).unwrap()
  assert_eq(path.length(), 2)
  assert_true(@witness.path_contains_required_kind(path, @graph.WbtestContext))
  assert_true(@witness.find_path(graph, "a", "c", @graph.TestContext) is None)
  assert_true(@witness.find_path(graph, "a", "d", @graph.WbtestContext) is None)
}

///|
test "breadth first search terminates on cycles and chooses a stable shortest path" {
  let graph = @graph.normalize(["a", "b", "c", "d"], [
    @graph.Edge::new(source="a", target="c", kind=@graph.Normal),
    @graph.Edge::new(source="a", target="b", kind=@graph.Normal),
    @graph.Edge::new(source="b", target="d", kind=@graph.Normal),
    @graph.Edge::new(source="c", target="d", kind=@graph.Normal),
    @graph.Edge::new(source="b", target="a", kind=@graph.Normal),
  ])
  let path = @witness.find_path(graph, "a", "d", @graph.NormalContext).unwrap()
  assert_eq(path.length(), 2)
  assert_eq(path[0].target(), "b")
  assert_true(
    @witness.find_path(graph, "a", "missing", @graph.NormalContext) is None,
  )
}
