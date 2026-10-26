///|
fn sample_violation() -> @policy.Violation {
  {
    rule_id: "no-storage",
    source: "demo/domain",
    target: "demo/storage",
    context: @graph.NormalContext,
    path: [],
  }
}

///|
test "exact valid exception suppresses only its matching violation" {
  let exception : @config.Exception = {
    rule_id: "no-storage",
    source: "demo/domain",
    target: "demo/storage",
    context: @graph.NormalContext,
    reason: "temporary migration",
    owner: "ziju-max",
    expires: "2026-11-01",
  }
  let result = @exception.apply_exceptions(
    [sample_violation()],
    [exception],
    "2026-10-26",
  )
  assert_eq(result.visible.length(), 0)
  assert_eq(result.suppressed.length(), 1)
}

///|
test "expired exception does not suppress and produces an error notice" {
  let exception : @config.Exception = {
    rule_id: "no-storage",
    source: "demo/domain",
    target: "demo/storage",
    context: @graph.NormalContext,
    reason: "temporary migration",
    owner: "ziju-max",
    expires: "2026-10-25",
  }
  let result = @exception.apply_exceptions(
    [sample_violation()],
    [exception],
    "2026-10-26",
  )
  assert_eq(result.visible.length(), 1)
  assert_eq(result.notices.length(), 1)
  assert_true(result.notices[0].kind == @exception.ExpiredException)
}

///|
test "unused exception remains visible as a warning notice" {
  let exception : @config.Exception = {
    rule_id: "no-storage",
    source: "demo/other",
    target: "demo/storage",
    context: @graph.NormalContext,
    reason: "temporary migration",
    owner: "ziju-max",
    expires: "2026-11-01",
  }
  let result = @exception.apply_exceptions(
    [sample_violation()],
    [exception],
    "2026-10-26",
  )
  assert_eq(result.visible.length(), 1)
  assert_eq(result.notices.length(), 1)
  assert_true(result.notices[0].kind == @exception.UnusedException)
}

///|
test "exception matching is exact across rule endpoints and context" {
  let exception : @config.Exception = {
    rule_id: "no-storage",
    source: "demo/domain",
    target: "demo/storage",
    context: @graph.TestContext,
    reason: "migration",
    owner: "ziju-max",
    expires: "2026-11-01",
  }
  let normal : @policy.Violation = {
    rule_id: "no-storage",
    source: "demo/domain",
    target: "demo/storage",
    context: @graph.NormalContext,
    path: [],
  }
  let different_target : @policy.Violation = {
    rule_id: "no-storage",
    source: "demo/domain",
    target: "demo/database",
    context: @graph.TestContext,
    path: [],
  }
  let result = @exception.apply_exceptions(
    [normal, different_target],
    [exception],
    "2026-10-26",
  )
  assert_eq(result.visible.length(), 2)
  assert_eq(result.suppressed.length(), 0)
  assert_eq(result.notices.length(), 1)
  assert_true(result.notices[0].kind == @exception.UnusedException)
}
