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
      #|    {"id": "storage", "packages": ["demo/storage"]},
      #|    {"id": "ghost", "packages": ["demo/missing"]}
      #|  ],
      #|  "rules": [{
      #|    "id": "no-storage",
      #|    "type": "deny",
      #|    "from": ["domain", "ghost"],
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
  assert_eq(execution.report.policy_warnings.length(), 1)
  assert_eq(execution.report.policy_warnings[0].group_id, "ghost")
  let json = @report.render_json(execution.report)
  assert_true(json.contains("\"rule_id\": \"no-storage\""))
  assert_true(json.contains("\"target\": \"demo/storage\""))
  assert_true(json.contains("\"policy_warnings\""))
  assert_true(json.contains("\"group_id\": \"ghost\""))
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
test "non-zero Moon tree status takes precedence over valid stdout and caps stderr" {
  let stdout = "{\"version\":3,\"status\":\"success\",\"nodes\":[],\"edges\":[]}"
  let stderr = String::make(1200, 'x')
  try {
    parse_moon_tree_process_result(7, stdout, stderr) |> ignore
    fail("a failed Moon tree process must not become a graph")
  } catch {
    ProcessFailure(message) => {
      assert_true(message.contains("exit code 7"))
      assert_true(message.length() <= 1100)
      assert_true(message.has_suffix("…"))
    }
    _ => fail("a non-zero Moon tree status must remain a process failure")
  }
}

///|
test "zero-status Moon tree output still rejects malformed JSON" {
  let stdout = "{not-json"
  let stderr = ""
  try {
    parse_moon_tree_process_result(0, stdout, stderr) |> ignore
    fail("malformed child output must not become an empty graph")
  } catch {
    GraphInput(message) => assert_true(message.contains("not valid JSON"))
    _ => fail("malformed child output must remain a graph input error")
  }
}

///|
test "zero-status Moon tree output rejects invalid UTF-8" {
  let stdout = Bytes::from_array([b'\xFF'])
  let stderr = ""
  try {
    parse_moon_tree_process_result(0, stdout, stderr) |> ignore
    fail("invalid UTF-8 child output must not become an empty graph")
  } catch {
    GraphInput(message) => assert_true(message.contains("not UTF-8"))
    _ => fail("invalid UTF-8 child output must remain a graph input error")
  }
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

///|
async test "baseline input failure never overwrites the existing destination" {
  let config_path = "_build/moonarch_preserve_baseline_config.json"
  let graph_path = "_build/moonarch_preserve_baseline_graph.json"
  let baseline_path = "_build/moonarch_preserve_baseline.json"
  defer @fs.remove(config_path)
  defer @fs.remove(graph_path)
  defer @fs.remove(baseline_path)
  @fs.write_file(
    config_path, "{\"schema_version\":1,\"scope\":{\"include\":[\"demo/**\"]},\"groups\":[],\"rules\":[]}",
  )
  @fs.write_file(graph_path, "invalid graph")
  @fs.write_file(baseline_path, "keep this baseline")
  let options : CheckOptions = {
    config_path,
    graph_source: OfflineGraph(graph_path),
    moon_executable: "moon",
    format: JsonOutput,
    color: NeverColor,
    output_path: None,
  }
  try {
    create_baseline(options, baseline_path)
    fail("invalid input must stop baseline creation")
  } catch {
    GraphInput(_) => ()
    _ => fail("invalid graph must remain a graph input error")
  }
  assert_eq(@fs.read_file(baseline_path).text(), "keep this baseline")
}

///|
async test "baseline destination write failure is reported as output failure" {
  let config_path = "_build/moonarch_output_failure_config.json"
  let graph_path = "_build/moonarch_output_failure_graph.json"
  defer @fs.remove(config_path)
  defer @fs.remove(graph_path)
  @fs.write_file(
    config_path, "{\"schema_version\":1,\"scope\":{\"include\":[\"demo/**\"]},\"groups\":[],\"rules\":[]}",
  )
  @fs.write_file(
    graph_path, "{\"schema_version\":1,\"packages\":[\"demo/app\"],\"edges\":[]}",
  )
  let options : CheckOptions = {
    config_path,
    graph_source: OfflineGraph(graph_path),
    moon_executable: "moon",
    format: JsonOutput,
    color: NeverColor,
    output_path: None,
  }
  try {
    create_baseline(options, config_path + "/baseline.json")
    fail("a missing parent directory must reject the baseline write")
  } catch {
    OutputFailure(message) => assert_true(message.contains("atomically"))
    _ => fail("baseline destination errors must remain output failures")
  }
}
