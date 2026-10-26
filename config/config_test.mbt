///|
test "minimal config parses with stable defaults" {
  let config = @config.parse_config(
    (
      #|{
      #|  "schema_version": 1,
      #|  "scope": {"include": ["demo/**"]},
      #|  "groups": [{"id": "ui", "packages": ["demo/ui"]}],
      #|  "rules": [{
      #|    "id": "no-ui-cycle",
      #|    "type": "deny",
      #|    "from": ["ui"],
      #|    "to": ["ui"],
      #|    "transitive": false,
      #|    "contexts": ["normal"]
      #|  }]
      #|}
    ),
  )
  assert_eq(config.schema_version, 1)
  assert_eq(config.scope.includes, ["demo/**"])
  assert_eq(config.scope.exclude, [])
  assert_eq(config.rules.length(), 1)
}

///|
test "config rejects unknown fields with their JSON path" {
  try {
    @config.parse_config(
      (
        #|{
        #|  "schema_version": 1,
        #|  "unexpected": true,
        #|  "scope": {"include": ["demo/**"]},
        #|  "groups": [],
        #|  "rules": []
        #|}
      ),
    )
    |> ignore
    fail("unknown field must be rejected")
  } catch {
    @config.ConfigError::UnknownField(path~) => assert_eq(path, "$.unexpected")
    _ => fail("expected unknown-field error")
  }
}

///|
test "config rejects duplicate JSON keys before object construction" {
  try {
    @config.parse_config("{\"schema_version\":1,\"schema_version\":1}")
    |> ignore
    fail("duplicate JSON keys must be rejected")
  } catch {
    @config.ConfigError::InvalidJson(_) => ()
    _ => fail("expected invalid-json error")
  }
}

///|
test "config rejects broken group references" {
  try {
    @config.parse_config(
      (
        #|{
        #|  "schema_version": 1,
        #|  "scope": {"include": ["demo/**"]},
        #|  "groups": [{"id": "ui", "packages": ["demo/ui"]}],
        #|  "rules": [{
        #|    "id": "forbidden",
        #|    "type": "deny",
        #|    "from": ["missing"],
        #|    "to": ["ui"],
        #|    "transitive": true,
        #|    "contexts": ["normal"]
        #|  }]
        #|}
      ),
    )
    |> ignore
    fail("broken reference must be rejected")
  } catch {
    @config.ConfigError::UnknownGroup(path~, id~) => {
      assert_eq(path, "$.rules[0].from[0]")
      assert_eq(id, "missing")
    }
    _ => fail("expected unknown-group error")
  }
}

///|
test "config rejects malformed package selectors" {
  try {
    @config.parse_config(
      (
        #|{
        #|  "schema_version": 1,
        #|  "scope": {"include": ["demo//bad"]},
        #|  "groups": [],
        #|  "rules": []
        #|}
      ),
    )
    |> ignore
    fail("malformed selector must be rejected")
  } catch {
    @config.ConfigError::InvalidValue(path~, detail=_) =>
      assert_eq(path, "$.scope.include[0]")
    _ => fail("expected invalid-value error")
  }
}

///|
test "config rejects unsupported versions, missing sections, and duplicate ids" {
  try {
    @config.parse_config(
      "{\"schema_version\":2,\"scope\":{\"include\":[\"demo/**\"]},\"groups\":[],\"rules\":[]}",
    )
    |> ignore
    fail("unsupported schema version must fail")
  } catch {
    @config.ConfigError::InvalidValue(path="$.schema_version", detail=_) => ()
    _ => fail("expected schema version error")
  }
  try {
    @config.parse_config("{\"schema_version\":1}") |> ignore
    fail("missing required sections must fail")
  } catch {
    @config.ConfigError::MissingField("$.scope") => ()
    _ => fail("expected missing scope")
  }
  try {
    @config.parse_config(
      (
        #|{
        #|  "schema_version":1,
        #|  "scope":{"include":["demo/**"]},
        #|  "groups":[],
        #|  "rules":[
        #|    {"id":"same","type":"layer_direction","contexts":["normal"]},
        #|    {"id":"same","type":"layer_direction","contexts":["test"]}
        #|  ]
        #|}
      ),
    )
    |> ignore
    fail("duplicate rule ids must fail")
  } catch {
    @config.ConfigError::DuplicateId(id~) => assert_eq(id, "same")
    _ => fail("expected duplicate id error")
  }
}

///|
test "config rejects invalid contexts and impossible exception dates" {
  try {
    @config.parse_config(
      (
        #|{
        #|  "schema_version":1,
        #|  "scope":{"include":["demo/**"]},
        #|  "groups":[],
        #|  "rules":[{"id":"r","type":"layer_direction","contexts":["integration"]}]
        #|}
      ),
    )
    |> ignore
    fail("unknown contexts must fail")
  } catch {
    @config.ConfigError::InvalidValue(path="$.rules[0].contexts[0]", detail=_) =>
      ()
    _ => fail("expected context error")
  }
  try {
    @config.parse_config(
      (
        #|{
        #|  "schema_version":1,
        #|  "scope":{"include":["demo/**"]},
        #|  "groups":[{"id":"a","packages":["demo/a"]}],
        #|  "rules":[{"id":"r","type":"deny","from":["a"],"to":["a"],"transitive":false,"contexts":["normal"]}],
        #|  "exceptions":[{"rule_id":"r","source":"demo/a","target":"demo/a","context":"normal","reason":"why","owner":"me","expires":"2026-02-30"}]
        #|}
      ),
    )
    |> ignore
    fail("impossible exception dates must fail")
  } catch {
    @config.ConfigError::InvalidDate(
      path="$.exceptions[0].expires",
      value="2026-02-30"
    ) => ()
    _ => fail("expected invalid date")
  }
}

///|
test "config requires contiguous layer levels and rejects duplicate JSON keys" {
  try {
    @config.parse_config(
      (
        #|{
        #|  "schema_version":1,
        #|  "scope":{"include":["demo/**"]},
        #|  "groups":[],
        #|  "layers":[{"id":"high","packages":["demo/high"],"level":2}],
        #|  "rules":[{"id":"direction","type":"layer_direction","contexts":["normal"]}]
        #|}
      ),
    )
    |> ignore
    fail("noncontiguous layer levels must fail")
  } catch {
    @config.ConfigError::InvalidValue(path="$.layers", detail=_) => ()
    _ => fail("expected layer levels error")
  }
  try {
    @config.parse_config(
      "{\"schema_version\":1,\"schema_version\":1,\"scope\":{\"include\":[\"demo/**\"]},\"groups\":[],\"rules\":[]}",
    )
    |> ignore
    fail("duplicate top-level keys must fail")
  } catch {
    @config.ConfigError::InvalidJson("$") => ()
    _ => fail("expected invalid JSON")
  }
}

///|
test "config rejects unsupported rules and duplicate contexts" {
  try {
    @config.parse_config(
      (
        #|{
        #| "schema_version":1,
        #| "scope":{"include":["demo/**"]},
        #| "groups":[],
        #| "rules":[{"id":"r","type":"allow_all","contexts":["normal"]}]
        #|}
      ),
    )
    |> ignore
    fail("unknown rule type must fail")
  } catch {
    @config.ConfigError::InvalidValue(path="$.rules[0].type", detail=_) => ()
    _ => fail("expected invalid rule type")
  }
  try {
    @config.parse_config(
      (
        #|{
        #| "schema_version":1,
        #| "scope":{"include":["demo/**"]},
        #| "groups":[],
        #| "rules":[{"id":"r","type":"layer_direction","contexts":["normal","normal"]}]
        #|}
      ),
    )
    |> ignore
    fail("duplicate contexts must fail")
  } catch {
    @config.ConfigError::DuplicateContext(
      path="$.rules[0].contexts[1]",
      context="normal"
    ) => ()
    _ => fail("expected duplicate context")
  }
}
