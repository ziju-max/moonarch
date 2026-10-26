///|
fn parse_policy_config(
  text : String,
) -> @config.Config raise @config.ConfigError {
  @config.parse_config(text)
}

///|
test "transitive deny returns one shortest witness" {
  let config = parse_policy_config(
    (
      #|{
      #| "schema_version": 1,
      #| "scope": {"include": ["demo/**"]},
      #| "groups": [
      #|  {"id": "domain", "packages": ["demo/domain"]},
      #|  {"id": "storage", "packages": ["demo/storage"]}
      #| ],
      #| "rules": [{"id": "no-storage", "type": "deny", "from": ["domain"], "to": ["storage"], "transitive": true, "contexts": ["normal"]}]
      #|}
    ),
  )
  let graph = @graph.normalize(
    ["demo/domain", "demo/service", "demo/storage"],
    [
      @graph.Edge::new(
        source="demo/domain",
        target="demo/service",
        kind=@graph.Normal,
      ),
      @graph.Edge::new(
        source="demo/service",
        target="demo/storage",
        kind=@graph.Normal,
      ),
    ],
  )
  let findings = @policy.evaluate(graph, config)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].path.length(), 2)
  assert_eq(findings[0].rule_id, "no-storage")
}

///|
test "referenced groups with no in-scope packages warn in stable order" {
  let config = parse_policy_config(
    (
      #|{
      #| "schema_version": 1,
      #| "scope": {"include": ["demo/**"]},
      #| "groups": [
      #|  {"id": "source", "packages": ["demo/source"]},
      #|  {"id": "target", "packages": ["demo/target"]},
      #|  {"id": "empty", "packages": ["demo/missing"]},
      #|  {"id": "absent", "packages": ["demo/not-present"]},
      #|  {"id": "unreferenced", "packages": ["demo/also-missing"]}
      #| ],
      #| "rules": [{"id": "deny", "type": "deny", "from": ["source", "empty", "absent"], "to": ["target", "empty"], "transitive": false, "contexts": ["normal"]}]
      #|}
    ),
  )
  let graph = @graph.normalize(["demo/source", "demo/target"], [])
  let result = @policy.evaluate_with_warnings(graph, config)
  assert_eq(result.violations.length(), 0)
  assert_eq(result.warnings.length(), 2)
  assert_eq(result.warnings[0].group_id, "absent")
  assert_eq(result.warnings[1].group_id, "empty")
  assert_eq(result.warnings[0].code, "unmatched_group")
}

///|
test "allow_only rejects a direct dependency outside allowed groups" {
  let config = parse_policy_config(
    (
      #|{
      #| "schema_version": 1,
      #| "scope": {"include": ["demo/**"]},
      #| "groups": [
      #|  {"id": "ui", "packages": ["demo/ui"]},
      #|  {"id": "service", "packages": ["demo/service"]},
      #|  {"id": "domain", "packages": ["demo/domain"]}
      #| ],
      #| "rules": [{"id": "ui-allowlist", "type": "allow_only", "from": ["ui"], "allow": ["service"], "contexts": ["normal"]}]
      #|}
    ),
  )
  let graph = @graph.normalize(["demo/ui", "demo/service", "demo/domain"], [
    @graph.Edge::new(
      source="demo/ui",
      target="demo/service",
      kind=@graph.Normal,
    ),
    @graph.Edge::new(source="demo/ui", target="demo/domain", kind=@graph.Normal),
  ])
  let findings = @policy.evaluate(graph, config)
  assert_eq(findings.length(), 1)
  assert_eq(findings[0].target, "demo/domain")
}

///|
test "layer rules report reverse direction and excessive legal jumps separately" {
  let config = parse_policy_config(
    (
      #|{
      #| "schema_version": 1,
      #| "scope": {"include": ["demo/**"]},
      #| "groups": [],
      #| "layers": [
      #|  {"id": "domain", "packages": ["demo/domain"], "level": 0},
      #|  {"id": "service", "packages": ["demo/service"], "level": 1},
      #|  {"id": "ui", "packages": ["demo/ui"], "level": 2}
      #| ],
      #| "rules": [
      #|  {"id": "direction", "type": "layer_direction", "contexts": ["normal"]},
      #|  {"id": "jump", "type": "max_layer_jump", "max": 1, "contexts": ["normal"]}
      #| ]
      #|}
    ),
  )
  let graph = @graph.normalize(["demo/domain", "demo/ui"], [
    @graph.Edge::new(source="demo/domain", target="demo/ui", kind=@graph.Normal),
    @graph.Edge::new(source="demo/ui", target="demo/domain", kind=@graph.Normal),
  ])
  let findings = @policy.evaluate(graph, config)
  assert_eq(findings.length(), 2)
  assert_eq(findings[0].rule_id, "direction")
  assert_eq(findings[0].source, "demo/domain")
  assert_eq(findings[1].rule_id, "jump")
  assert_eq(findings[1].source, "demo/ui")
}

///|
test "direct deny ignores indirect paths and filters unsupported edge contexts" {
  let config = parse_policy_config(
    (
      #|{
      #| "schema_version": 1,
      #| "scope": {"include": ["demo/**"]},
      #| "groups": [
      #|  {"id": "domain", "packages": ["demo/domain"]},
      #|  {"id": "storage", "packages": ["demo/storage"]}
      #| ],
      #| "rules": [
      #|  {"id": "direct-only", "type": "deny", "from": ["domain"], "to": ["storage"], "transitive": false, "contexts": ["normal"]}
      #| ]
      #|}
    ),
  )
  let graph = @graph.normalize(
    ["demo/domain", "demo/service", "demo/storage"],
    [
      @graph.Edge::new(
        source="demo/domain",
        target="demo/service",
        kind=@graph.Normal,
      ),
      @graph.Edge::new(
        source="demo/service",
        target="demo/storage",
        kind=@graph.Normal,
      ),
      @graph.Edge::new(
        source="demo/domain",
        target="demo/storage",
        kind=@graph.Test,
      ),
    ],
  )
  assert_eq(@policy.evaluate(graph, config).length(), 0)
}

///|
test "scope exclusions prevent excluded packages from becoming policy targets" {
  let config = parse_policy_config(
    (
      #|{
      #| "schema_version": 1,
      #| "scope": {"include": ["demo/**"], "exclude": ["demo/vendor/**"]},
      #| "groups": [
      #|  {"id": "ui", "packages": ["demo/ui"]},
      #|  {"id": "core", "packages": ["demo/core"]}
      #| ],
      #| "rules": [{"id": "ui-allow-list", "type": "allow_only", "from": ["ui"], "allow": ["core"], "contexts": ["normal"]}]
      #|}
    ),
  )
  let graph = @graph.normalize(["demo/ui", "demo/core", "demo/vendor/lib"], [
    @graph.Edge::new(source="demo/ui", target="demo/core", kind=@graph.Normal),
    @graph.Edge::new(
      source="demo/ui",
      target="demo/vendor/lib",
      kind=@graph.Normal,
    ),
  ])
  assert_eq(@policy.evaluate(graph, config).length(), 0)
}

///|
test "layer overlap is rejected before evaluating directional rules" {
  let config = parse_policy_config(
    (
      #|{
      #| "schema_version":1,
      #| "scope":{"include":["demo/**"]},
      #| "groups":[],
      #| "layers":[
      #|  {"id":"base","packages":["demo/**"],"level":0},
      #|  {"id":"domain","packages":["demo/domain"],"level":1}
      #| ],
      #| "rules":[{"id":"direction","type":"layer_direction","contexts":["normal"]}]
      #|}
    ),
  )
  let graph = @graph.normalize(["demo/domain"], [])
  try {
    @policy.evaluate(graph, config) |> ignore
    fail("overlapping layers must not silently choose a level")
  } catch {
    @policy.PolicyError::OverlappingLayers("demo/domain") => ()
    _ => fail("expected overlapping layer error")
  }
}
