///|
fn baseline_violation(
  rule_id : String,
  source : String,
  target : String,
  context : @graph.Context,
) -> @policy.Violation {
  { rule_id, source, target, context, path: [], }
}

///|
test "classify separates new existing and resolved fingerprints" {
  let current = [
    baseline_violation("a", "demo/a", "demo/b", @graph.NormalContext),
    baseline_violation("b", "demo/c", "demo/d", @graph.TestContext),
  ]
  let baseline = @baseline.Baseline::from_fingerprints([
    @baseline.fingerprint(
      baseline_violation("b", "demo/c", "demo/d", @graph.TestContext),
    ),
    @baseline.fingerprint(
      baseline_violation("c", "demo/e", "demo/f", @graph.NormalContext),
    ),
  ])
  let result = @baseline.classify(current, baseline)
  assert_eq(result.new_findings.length(), 1)
  assert_eq(result.existing_findings.length(), 1)
  assert_eq(result.resolved_fingerprints.length(), 1)
}

///|
test "fingerprint ignores witness path but includes context" {
  let first = baseline_violation("r", "demo/a", "demo/b", @graph.NormalContext)
  let with_path : @policy.Violation = {
    rule_id: "r",
    source: "demo/a",
    target: "demo/b",
    context: @graph.NormalContext,
    path: [
      @graph.Edge::new(source="demo/a", target="demo/x", kind=@graph.Normal),
    ],
  }
  assert_eq(@baseline.fingerprint(first), @baseline.fingerprint(with_path))
  assert_true(
    @baseline.fingerprint(first) !=
    @baseline.fingerprint(
      baseline_violation("r", "demo/a", "demo/b", @graph.TestContext),
    ),
  )
}

///|
test "baseline codec is versioned and rejects unsupported versions" {
  let text = @baseline.serialize_baseline(
    @baseline.Baseline::from_fingerprints(["v1:1:a"]),
  )
  let decoded = @baseline.parse_baseline(text)
  assert_eq(decoded.schema_version, 1)
  assert_eq(decoded.fingerprints, ["v1:1:a"])
  try {
    @baseline.parse_baseline("{\"schema_version\":9,\"fingerprints\":[]}")
    |> ignore
    fail("unsupported version must fail")
  } catch {
    @baseline.BaselineError::UnsupportedVersion(9) => ()
    _ => fail("unexpected baseline error")
  }
}
