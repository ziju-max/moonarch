///|
pub fn render_json(report : Report) -> String {
  let new_items = report.new_findings.map(finding => {
    render_finding_json(finding, "new")
  })
  let existing_items = report.existing_findings.map(finding => {
    render_finding_json(finding, "existing")
  })
  let suppressed_items = report.suppressed.map(render_suppressed_json)
  let resolved_items = report.resolved_fingerprints.map(json_string)
  let notice_items = report.notices.map(render_notice_json)
  let output = StringBuilder()
  output.write_string("{\n")
  output.write_string(
    "  \"schema_version\": " + report.schema_version.to_string() + ",\n",
  )
  output.write_string("  \"input\": " + json_string(report.input) + ",\n")
  output.write_string("  \"today\": " + json_string(report.today) + ",\n")
  output.write_string(
    "  \"baseline_enabled\": " + bool_json(report.baseline_enabled) + ",\n",
  )
  output.write_string(
    "  \"counts\": {\"new\": " + report.new_findings.length().to_string(),
  )
  output.write_string(
    ", \"existing\": " + report.existing_findings.length().to_string(),
  )
  output.write_string(
    ", \"suppressed\": " + report.suppressed.length().to_string(),
  )
  output.write_string(
    ", \"resolved\": " + report.resolved_fingerprints.length().to_string(),
  )
  output.write_string(
    ", \"notices\": " + report.notices.length().to_string() + "},\n",
  )
  output.write_string("  \"new_findings\": [" + new_items.join(", ") + "],\n")
  output.write_string(
    "  \"existing_findings\": [" + existing_items.join(", ") + "],\n",
  )
  output.write_string(
    "  \"suppressed_findings\": [" + suppressed_items.join(", ") + "],\n",
  )
  output.write_string(
    "  \"resolved_fingerprints\": [" + resolved_items.join(", ") + "],\n",
  )
  output.write_string("  \"notices\": [" + notice_items.join(", ") + "]\n")
  output.write_string("}\n")
  output.to_string()
}

///|
fn render_finding_json(finding : @policy.Violation, status : String) -> String {
  let path = finding.path.map(edge => {
    "{\"source\": " +
    json_string(edge.source()) +
    ", \"target\": " +
    json_string(edge.target()) +
    ", \"kind\": " +
    json_string(edge.kind().as_string()) +
    "}"
  })
  "{\"status\": " +
  json_string(status) +
  ", \"rule_id\": " +
  json_string(finding.rule_id) +
  ", \"source\": " +
  json_string(finding.source) +
  ", \"target\": " +
  json_string(finding.target) +
  ", \"context\": " +
  json_string(finding.context.as_string()) +
  ", \"path\": [" +
  path.join(", ") +
  "]}"
}

///|
fn render_suppressed_json(value : @exception.SuppressedFinding) -> String {
  "{\"finding\": " +
  render_finding_json(value.violation, "suppressed") +
  ", \"reason\": " +
  json_string(value.reason) +
  ", \"owner\": " +
  json_string(value.owner) +
  ", \"expires\": " +
  json_string(value.expires) +
  "}"
}

///|
fn render_notice_json(notice : @exception.ExceptionNotice) -> String {
  let kind = match notice.kind {
    @exception.ExpiredException => "expired_exception"
    @exception.UnusedException => "unused_exception"
  }
  "{\"kind\": " +
  json_string(kind) +
  ", \"rule_id\": " +
  json_string(notice.rule_id) +
  ", \"source\": " +
  json_string(notice.source) +
  ", \"target\": " +
  json_string(notice.target) +
  ", \"message\": " +
  json_string(notice.message) +
  "}"
}

///|
fn json_string(value : String) -> String {
  @json.to_json(value).stringify()
}

///|
fn bool_json(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}
