///|
async test "offline check evaluates policies and returns a report exit code" {
  @async.is_being_cancelled() |> ignore
  let config_path = "_build/moonarch_app_test_config.json"
  let graph_path = "_build/moonarch_app_test_graph.json"
  let baseline_path = "_build/moonarch_app_test_baseline.json"
  let baseline_config_path = "_build/moonarch_app_test_with_baseline.json"
  defer @fs.remove(config_path)
  defer @fs.remove(graph_path)
  defer @fs.remove(baseline_path)
  defer @fs.remove(baseline_config_path)
  @fs.write_file(
    config_path,
    (
      #|{
      #|  "schema_version": 1,
      #|  "scope": {"include": ["demo/**"]},
      #|  "groups": [
      #|    {"id": "domain", "packages": ["demo/domain"]},
      #|    {"id": "storage", "packages": ["demo/storage"]}
      #|  ],
      #|  "rules": [{
      #|    "id": "no-storage",
      #|    "type": "deny",
      #|    "from": ["domain"],
      #|    "to": ["storage"],
      #|    "transitive": true,
      #|    "contexts": ["normal"]
      #|  }]
      #|}
    ),
  )
  @fs.write_file(
    graph_path,
    (
      #|{"schema_version":1,"packages":["demo/domain","demo/storage"],
      #| "edges":[{"source":"demo/domain","target":"demo/storage","kind":"normal"}]}
    ),
  )
  let options : CheckOptions = {
    config_path,
    graph_source: OfflineGraph(graph_path),
    moon_executable: "moon",
    format: JsonOutput,
    color: NeverColor,
    output_path: None,
  }
  let execution = run_check_on_date(options, "2026-10-26")
  assert_eq(execution.exit_code, 1)
  let json = @report.render_json(execution.report)
  assert_true(json.contains("\"rule_id\": \"no-storage\""))
  assert_true(json.contains("\"target\": \"demo/storage\""))
  let forced_color = render_report(
    execution.report,
    TerminalOutput,
    AlwaysColor,
  )
  assert_true(forced_color.contains("\u{001B}[31m"))
  let colored_json = render_report(execution.report, JsonOutput, AlwaysColor)
  assert_true(!colored_json.contains("\u{001B}"))
  @fs.write_file(baseline_path, "old baseline")
  create_baseline(options, baseline_path)
  let baseline_text = @fs.read_file(baseline_path).text()
  assert_true(baseline_text.contains("\"schema_version\": 1"))
  assert_true(!baseline_text.contains("old baseline"))
  @fs.write_file(
    baseline_config_path,
    (
      #|{
      #|  "schema_version": 1,
      #|  "scope": {"include": ["demo/**"]},
      #|  "groups": [
      #|    {"id": "domain", "packages": ["demo/domain"]},
      #|    {"id": "storage", "packages": ["demo/storage"]}
      #|  ],
      #|  "rules": [{
      #|    "id": "no-storage",
      #|    "type": "deny",
      #|    "from": ["domain"],
      #|    "to": ["storage"],
      #|    "transitive": true,
      #|    "contexts": ["normal"]
      #|  }],
      #|  "baseline": "moonarch_app_test_baseline.json"
      #|}
    ),
  )
  let baseline_options : CheckOptions = {
    config_path: baseline_config_path,
    graph_source: OfflineGraph(graph_path),
    moon_executable: "moon",
    format: JsonOutput,
    color: NeverColor,
    output_path: None,
  }
  let accepted = run_check_on_date(baseline_options, "2026-10-26")
  assert_eq(accepted.exit_code, 0)
  assert_eq(accepted.report.existing_findings.length(), 1)
}

///|
test "UTC date conversion is Gregorian and stable across leap day" {
  assert_eq(utc_date_from_days_since_epoch(0), "1970-01-01")
  assert_eq(utc_date_from_days_since_epoch(20513), "2026-03-01")
  assert_eq(utc_date_from_days_since_epoch(20512), "2026-02-28")
  assert_eq(utc_date_from_days_since_epoch(19782), "2024-02-29")
}

///|
test "child process stderr excerpts have a fixed upper bound" {
  assert_eq(stderr_excerpt("short"), ": short")
  let long_text = String::make(1200, 'x')
  let excerpt = stderr_excerpt(long_text)
  assert_true(excerpt.length() <= 1003)
  assert_true(excerpt.has_suffix("…"))
}

///|
async test "configuration read and decode failures stay distinct from graph errors" {
  let path = "_build/moonarch_invalid_config_test.json"
  defer @fs.remove(path)
  @fs.write_file(path, "{\"schema_version\":1}")
  let options : CheckOptions = {
    config_path: path,
    graph_source: OfflineGraph("unused.json"),
    moon_executable: "moon",
    format: JsonOutput,
    color: NeverColor,
    output_path: None,
  }
  try {
    run_check_on_date(options, "2026-10-26") |> ignore
    fail("missing configuration sections must fail")
  } catch {
    Configuration(message) => assert_true(message.contains("$.scope"))
    _ => fail("configuration failures must not be reported as graph failures")
  }
}

///|
async test "workspace process launch errors do not become empty successful graphs" {
  let options : CheckOptions = {
    config_path: "examples/workspace/moonarch.json",
    graph_source: Workspace("examples/workspace"),
    moon_executable: "moonarch_missing_executable_for_test",
    format: JsonOutput,
    color: NeverColor,
    output_path: None,
  }
  try {
    run_check_on_date(options, "2026-10-26") |> ignore
    fail("missing child executable must fail")
  } catch {
    ProcessFailure(message) => assert_true(message.contains("could not start"))
    _ => fail("process launch failure must not become a policy result")
  }
}
