///|
fn report_fixture() -> @report.Report {
  let violation : @policy.Violation = {
    rule_id: "no-storage",
    source: "demo/domain",
    target: "demo/storage",
    context: @graph.NormalContext,
    path: [
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
  }
  {
    schema_version: 1,
    input: "offline graph.json",
    today: "2026-10-26",
    baseline_enabled: true,
    new_findings: [violation],
    existing_findings: [],
    suppressed: [],
    resolved_fingerprints: [],
    notices: [],
    policy_warnings: [],
  }
}

///|
test "JSON and Markdown renderers are deterministic and escape user text" {
  let report = report_fixture()
  let first_json = @report.render_json(report)
  let second_json = @report.render_json(report)
  assert_eq(first_json, second_json)
  assert_true(first_json.contains("\"schema_version\": 1"))
  assert_true(!first_json.contains("\u{001B}"))
  let first_markdown = @report.render_markdown(report)
  assert_eq(first_markdown, @report.render_markdown(report))
  assert_true(first_markdown.contains("## New findings"))
  assert_true(
    first_markdown.contains("demo/domain -> demo/service -> demo/storage"),
  )
}

///|
test "terminal report includes counts and no unexpected ANSI" {
  let output = @report.render_terminal(report_fixture())
  assert_true(output.contains("new: 1"))
  assert_true(!output.contains("\u{001B}"))
}

///|
test "renderers keep baseline status and resolved fingerprints visible" {
  let source = report_fixture()
  let report : @report.Report = {
    schema_version: source.schema_version,
    input: source.input,
    today: source.today,
    baseline_enabled: true,
    new_findings: [],
    existing_findings: source.new_findings,
    suppressed: source.suppressed,
    resolved_fingerprints: ["v1:resolved-entry"],
    notices: source.notices,
    policy_warnings: source.policy_warnings,
  }
  let json = @report.render_json(report)
  assert_true(json.contains("\"status\": \"existing\""))
  assert_true(json.contains("v1:resolved-entry"))
  let markdown = @report.render_markdown(report)
  assert_true(markdown.contains("Baseline: enabled"))
  assert_true(markdown.contains("## Resolved fingerprints"))
  assert_true(markdown.contains("v1:resolved-entry"))
  let terminal = @report.render_terminal(report)
  assert_true(terminal.contains("existing: 1"))
  assert_true(!terminal.contains("\u{001B}"))
}

///|
test "Markdown renderer keeps untrusted fields inside their intended structure" {
  let original = report_fixture()
  let violation : @policy.Violation = {
    rule_id: "rule``id",
    source: "demo/a\n## injected heading",
    target: "demo/b|cell",
    context: @graph.NormalContext,
    path: [
      @graph.Edge::new(
        source="demo/a\n## injected heading",
        target="demo/b|cell",
        kind=@graph.Normal,
      ),
    ],
  }
  let report : @report.Report = {
    schema_version: original.schema_version,
    input: "offline`input\n### injected heading",
    today: original.today,
    baseline_enabled: original.baseline_enabled,
    new_findings: [violation],
    existing_findings: [],
    suppressed: [
      {
        violation,
        reason: "approved **bold**\n# injected heading",
        owner: "owner`name",
        expires: "2026-12-31",
      },
    ],
    resolved_fingerprints: ["v1:resolved`entry"],
    notices: [
      {
        kind: @exception.UnusedException,
        rule_id: "unused`rule",
        source: "source\n## injected heading",
        target: "target|cell",
        message: "details [click](https://example.invalid)\n## injected heading",
      },
    ],
    policy_warnings: [],
  }

  let markdown = @report.render_markdown(report)
  assert_true(
    markdown.contains("- Input: ``offline`input ### injected heading``\n"),
  )
  assert_true(markdown.contains("**```rule``id```**"))
  assert_true(markdown.contains("`demo/a ## injected heading`"))
  assert_true(
    markdown.contains("approved \\*\\*bold\\*\\* \\# injected heading"),
  )
  assert_true(markdown.contains("owner ``owner`name``"))
  assert_true(markdown.contains("``unused`rule``"))
  assert_true(markdown.contains("``v1:resolved`entry``"))
  assert_true(
    markdown.contains(
      "details \\[click\\]\\(https://example\\.invalid\\) \\#\\# injected heading",
    ),
  )
  assert_true(!markdown.contains("\n### injected heading\n"))
}

///|
test "terminal renderer strips control characters from untrusted fields" {
  let original = report_fixture()
  let violation : @policy.Violation = {
    rule_id: "rule\u{001B}[31m",
    source: "demo/a\nFORGED",
    target: "demo/b",
    context: @graph.NormalContext,
    path: [
      @graph.Edge::new(
        source="demo/a\nFORGED",
        target="demo/b",
        kind=@graph.Normal,
      ),
    ],
  }
  let report : @report.Report = {
    schema_version: original.schema_version,
    input: "workspace\u{001B}[2J\nINJECTED",
    today: original.today,
    baseline_enabled: original.baseline_enabled,
    new_findings: [violation],
    existing_findings: [],
    suppressed: [
      {
        violation,
        reason: "reason\rINJECTED",
        owner: "owner\tname",
        expires: "2026-12-31",
      },
    ],
    resolved_fingerprints: [],
    notices: [
      {
        kind: @exception.UnusedException,
        rule_id: "notice\u{001B}[0m",
        source: "demo/source",
        target: "demo/target",
        message: "warning\nFORGED",
      },
    ],
    policy_warnings: [],
  }

  let terminal = @report.render_terminal(report)
  assert_true(!terminal.contains("\u{001B}"))
  assert_true(terminal.contains("Input: workspace [2J INJECTED"))
  assert_true(terminal.contains("rule [31m"))
  assert_true(terminal.contains("reason INJECTED (owner=owner name"))
  assert_true(!terminal.contains("\nFORGED\n"))
}

///|
test "policy warnings appear in all reports without failing the check" {
  let source = report_fixture()
  let warning : @policy.PolicyWarning = {
    code: "unmatched_group",
    group_id: "demo/ghost",
    message: "referenced group matches no in-scope packages",
  }
  let report : @report.Report = {
    schema_version: source.schema_version,
    input: source.input,
    today: source.today,
    baseline_enabled: source.baseline_enabled,
    new_findings: [],
    existing_findings: [],
    suppressed: [],
    resolved_fingerprints: [],
    notices: [],
    policy_warnings: [warning],
  }
  assert_true(!report.has_new_failures())
  let json = @report.render_json(report)
  assert_true(json.contains("\"unmatched_group\""))
  assert_true(json.contains("demo/ghost"))
  let markdown = @report.render_markdown(report)
  assert_true(markdown.contains("## Policy warnings"))
  assert_true(markdown.contains("demo/ghost"))
  let terminal = @report.render_terminal(report)
  assert_true(terminal.contains("WARNING unmatched group demo/ghost"))
}
