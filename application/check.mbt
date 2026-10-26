///|
pub async fn validate_config_file(path : String) -> Unit raise ApplicationError {
  raise_if_cancelled()
  let text = read_text(path, "configuration")
  try @config.parse_config(text) |> ignore catch {
    error => raise ApplicationError::Configuration(config_error_text(error))
  }
}

///|
pub async fn run_check(
  options : CheckOptions,
) -> CheckExecution raise ApplicationError {
  run_check_on_date(options, today_utc())
}

///|
async fn run_check_on_date(
  options : CheckOptions,
  today : String,
) -> CheckExecution raise ApplicationError {
  raise_if_cancelled()
  let config_text = read_text(options.config_path, "configuration")
  let config = @config.parse_config(config_text) catch {
    error => raise ApplicationError::Configuration(config_error_text(error))
  }
  let graph = load_graph(options.graph_source, options.moon_executable)
  let policy_result = @policy.evaluate_with_warnings(graph, config) catch {
    error =>
      raise ApplicationError::PolicyConfiguration(policy_error_text(error))
  }
  let exception_result = @exception.apply_exceptions(
    policy_result.violations,
    config.exceptions,
    today,
  ) catch {
    error => raise ApplicationError::Configuration(exception_error_text(error))
  }
  let (new_findings, existing_findings, resolved_fingerprints) = match
    config.baseline {
    None => (exception_result.visible, [], [])
    Some(relative_path) => {
      let path = resolve_from_config(options.config_path, relative_path)
      let text = read_text(path, "baseline")
      let parsed = @baseline.parse_baseline(text) catch {
        error =>
          raise ApplicationError::BaselineInput(baseline_error_text(error))
      }
      let result = @baseline.classify(exception_result.visible, parsed)
      (
        result.new_findings,
        result.existing_findings,
        result.resolved_fingerprints,
      )
    }
  }
  let report : @report.Report = {
    schema_version: 1,
    input: graph_source_description(options.graph_source),
    today,
    baseline_enabled: config.baseline is Some(_),
    new_findings,
    existing_findings,
    suppressed: exception_result.suppressed,
    resolved_fingerprints,
    notices: exception_result.notices,
    policy_warnings: policy_result.warnings,
  }
  { report, exit_code: if report.has_new_failures() { 1 } else { 0 }, }
}

///|
pub async fn create_baseline(
  options : CheckOptions,
  output_path : String,
) -> Unit raise ApplicationError {
  raise_if_cancelled()
  let config_text = read_text(options.config_path, "configuration")
  let config = @config.parse_config(config_text) catch {
    error => raise ApplicationError::Configuration(config_error_text(error))
  }
  let graph = load_graph(options.graph_source, options.moon_executable)
  let findings = @policy.evaluate(graph, config) catch {
    error =>
      raise ApplicationError::PolicyConfiguration(policy_error_text(error))
  }
  let exception_result = @exception.apply_exceptions(
    findings,
    config.exceptions,
    today_utc(),
  ) catch {
    error => raise ApplicationError::Configuration(exception_error_text(error))
  }
  let fingerprints = exception_result.visible.map(@baseline.fingerprint)
  let baseline = @baseline.Baseline::from_fingerprints(fingerprints)
  atomic_write_text(output_path, @baseline.serialize_baseline(baseline))
}

///|
pub fn render_report(
  report : @report.Report,
  format : OutputFormat,
  color : ColorMode,
) -> String {
  match format {
    JsonOutput => @report.render_json(report)
    MarkdownOutput => @report.render_markdown(report)
    TerminalOutput => {
      let text = @report.render_terminal(report)
      match color {
        AlwaysColor => color_terminal_heading(text, report.has_new_failures())
        AutoColor | NeverColor => text
      }
    }
  }
}

///|
pub async fn write_result(
  output_path : String?,
  text : String,
) -> Unit raise ApplicationError {
  match output_path {
    Some(path) => write_text(path, text)
    None =>
      @stdio.stdout.write(text) catch {
        _ => raise ApplicationError::OutputFailure("could not write to stdout")
      }
  }
}

///|
async fn load_graph(
  source : GraphSource,
  moon_executable : String,
) -> @graph.Graph raise ApplicationError {
  match source {
    OfflineGraph(path) => {
      let text = read_text(path, "graph")
      @graph.parse_offline_json(text) catch {
        error =>
          raise ApplicationError::GraphInput(offline_graph_error_text(error))
      }
    }
    Workspace(path) => {
      let (exit_code, stdout, stderr) = @process.collect_output(
        moon_executable,
        ["tree", "--package", "--json"],
        cwd=path,
        no_console_window=true,
      ) catch {
        _ =>
          raise ApplicationError::ProcessFailure(
            "could not start `" + moon_executable + " tree --package --json`",
          )
      }
      parse_moon_tree_process_result(exit_code, stdout, stderr)
    }
  }
}

///|
fn parse_moon_tree_process_result(
  exit_code : Int32,
  stdout : &@io.Data,
  stderr : &@io.Data,
) -> @graph.Graph raise ApplicationError {
  if exit_code != 0 {
    raise ApplicationError::ProcessFailure(
      "moon tree failed with exit code " +
      exit_code.to_string() +
      stderr_excerpt(safe_data_text(stderr)),
    )
  }
  let text = stdout.text() catch {
    _ => raise ApplicationError::GraphInput("moon tree output is not UTF-8")
  }
  @moon_tree.parse_moon_tree_json(text) catch {
    error => raise ApplicationError::GraphInput(moon_tree_error_text(error))
  }
}

///|
async fn read_text(
  path : String,
  purpose : String,
) -> String raise ApplicationError {
  let data = @fs.read_file(path) catch {
    _ =>
      raise input_error(purpose, "could not read " + purpose + " file: " + path)
  }
  data.text() catch {
    _ =>
      raise input_error(purpose, purpose + " file is not valid UTF-8: " + path)
  }
}

///|
async fn write_text(
  path : String,
  text : String,
) -> Unit raise ApplicationError {
  @fs.write_file(path, text, create_mode=@fs.CreateOrTruncate) catch {
    _ => raise ApplicationError::OutputFailure("could not write file: " + path)
  }
}

///|
async fn atomic_write_text(
  path : String,
  text : String,
) -> Unit raise ApplicationError {
  let temporary = path +
    ".moonarch-tmp-" +
    @env.now().reinterpret_as_int64().to_string()
  let mut written = false
  try {
    @fs.write_file(temporary, text, create_mode=@fs.CreateNew)
    written = true
    @fs.rename(temporary, path, replace=true)
  } catch {
    _ => {
      if written {
        @fs.remove(temporary) catch {
          _ => ()
        }
      }
      raise ApplicationError::OutputFailure(
        "could not atomically replace file: " + path,
      )
    }
  }
}

///|
fn resolve_from_config(config_path : String, relative_path : String) -> String {
  let path = @path.Path(relative_path)
  if path.is_absolute() {
    path.normalize().to_string()
  } else {
    @path.Path(config_path).dirname().join(path).normalize().to_string()
  }
}

///|
fn graph_source_description(source : GraphSource) -> String {
  match source {
    OfflineGraph(path) => "offline graph: " + path
    Workspace(path) => "MoonBit workspace: " + path
  }
}

///|
fn today_utc() -> String {
  let milliseconds = @env.now().reinterpret_as_int64()
  utc_date_from_days_since_epoch((milliseconds / 86400000).to_int())
}

///|
fn utc_date_from_days_since_epoch(days : Int32) -> String {
  let shifted = days + 719468
  let era = floor_div(shifted, 146097)
  let day_of_era = shifted - era * 146097
  let year_of_era = (
      day_of_era - day_of_era / 1460 + day_of_era / 36524 - day_of_era / 146096
    ) /
    365
  let mut year = year_of_era + era * 400
  let day_of_year = day_of_era -
    (365 * year_of_era + year_of_era / 4 - year_of_era / 100)
  let month_prime = (5 * day_of_year + 2) / 153
  let day = day_of_year - (153 * month_prime + 2) / 5 + 1
  let month = if month_prime < 10 { month_prime + 3 } else { month_prime - 9 }
  if month <= 2 {
    year = year + 1
  }
  pad_number(year, 4) + "-" + pad_number(month, 2) + "-" + pad_number(day, 2)
}

///|
fn floor_div(value : Int32, divisor : Int32) -> Int32 {
  if value >= 0 {
    value / divisor
  } else {
    (value - divisor + 1) / divisor
  }
}

///|
fn pad_number(value : Int32, width : Int32) -> String {
  let text = value.to_string()
  if text.length() >= width {
    text
  } else {
    String::make(width - text.length(), '0') + text
  }
}

///|
fn color_terminal_heading(text : String, failed : Bool) -> String {
  let color = if failed { "\u{001B}[31m" } else { "\u{001B}[32m" }
  color + text + "\u{001B}[0m"
}

///|
fn stderr_excerpt(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed.is_empty() {
    ""
  } else {
    let chars = trimmed.to_array()
    if chars.length() <= 1000 {
      ": " + trimmed
    } else {
      let output = StringBuilder()
      output.write_string(": ")
      for index in 0..<1000 {
        output.write_string(chars[index].to_string())
      }
      output.write_string("…")
      output.to_string()
    }
  }
}

///|
fn safe_data_text(data : &@io.Data) -> String {
  data.text() catch {
    _ => "<non-UTF-8 stderr>"
  }
}

///|
fn input_error(purpose : String, message : String) -> ApplicationError {
  match purpose {
    "configuration" => ApplicationError::Configuration(message)
    "baseline" => ApplicationError::BaselineInput(message)
    "graph" => ApplicationError::GraphInput(message)
    _ => ApplicationError::GraphInput(message)
  }
}

///|
fn raise_if_cancelled() -> Unit raise ApplicationError {
  if @async.is_being_cancelled() {
    raise ApplicationError::ProcessFailure("operation was cancelled")
  }
}

///|
fn config_error_text(error : @config.ConfigError) -> String {
  match error {
    @config.InvalidJson(path) => "invalid JSON at " + path
    @config.ExpectedObject(path) => "expected an object at " + path
    @config.ExpectedArray(path) => "expected an array at " + path
    @config.MissingField(path) => "missing required field " + path
    @config.TypeMismatch(path) => "invalid value type at " + path
    @config.UnknownField(path~) => "unknown field " + path
    @config.InvalidValue(path~, detail~) => path + ": " + detail
    @config.DuplicateId(id~) => "duplicate id " + id
    @config.UnknownGroup(path~, id~) => path + " references unknown group " + id
    @config.DuplicateContext(path~, context~) =>
      path + " repeats context " + context
    @config.InvalidDate(path~, value~) =>
      path + " is not a valid date: " + value
  }
}

///|
fn offline_graph_error_text(error : @graph.OfflineGraphError) -> String {
  match error {
    @graph.InvalidJson => "offline graph is not valid JSON"
    @graph.InvalidShape(path) => "invalid offline graph field at " + path
    @graph.UnknownField(path~) => "unknown offline graph field " + path
    @graph.UnsupportedVersion(version) =>
      "unsupported offline graph version " + version.to_string()
    @graph.InvalidEdgeKind(kind) => "unknown offline graph edge kind " + kind
    @graph.EmptyPackageName => "offline graph contains an empty package name"
    @graph.InvalidPackageName(name) =>
      "offline graph contains invalid package name: " + name
    @graph.DanglingEdge(source, target) =>
      "offline graph edge references missing package: " +
      source +
      " -> " +
      target
    @graph.InvalidGraph =>
      "offline graph contains invalid packages or edge endpoints"
  }
}

///|
fn moon_tree_error_text(error : @moon_tree.MoonTreeError) -> String {
  match error {
    @moon_tree.InvalidJson => "moon tree output is not valid JSON"
    @moon_tree.UnsupportedVersion(version) =>
      "unsupported moon tree schema version " + version.to_string()
    @moon_tree.InvalidStatus(status) => "moon tree failed: " + status
    @moon_tree.InvalidShape(path) => "invalid moon tree output at " + path
    @moon_tree.InvalidEdgeKind(kind) => "unknown moon tree edge kind " + kind
    @moon_tree.InvalidGraph => "moon tree output contains invalid graph edges"
  }
}

///|
fn baseline_error_text(error : @baseline.BaselineError) -> String {
  match error {
    @baseline.InvalidJson => "baseline is not valid JSON"
    @baseline.InvalidShape(path) => "invalid baseline field at " + path
    @baseline.UnknownField(path) => "unknown baseline field " + path
    @baseline.UnsupportedVersion(version) =>
      "unsupported baseline version " + version.to_string()
    @baseline.DuplicateFingerprint(value) =>
      "baseline repeats fingerprint " + value
  }
}

///|
fn exception_error_text(error : @exception.ExceptionError) -> String {
  match error {
    @exception.InvalidToday(value) => "invalid check date " + value
    @exception.DuplicateMatch(rule_id) =>
      "multiple exceptions match rule " + rule_id
  }
}

///|
fn policy_error_text(error : @policy.PolicyError) -> String {
  match error {
    @policy.MissingLayer(package_name) =>
      "no layer matches package " + package_name
    @policy.OverlappingLayers(package_name) =>
      "multiple layers match package " + package_name
  }
}
