///|
pub fn render_terminal(report : Report) -> String {
  let status = if report.has_new_failures() { "FAIL" } else { "PASS" }
  let output = StringBuilder()
  output.write_string("MoonArch " + status + "\n")
  output.write_string("Input: " + flatten_report_controls(report.input) + "\n")
  output.write_string("Date: " + flatten_report_controls(report.today) + "\n")
  output.write_string(
    "Counts: new: " + report.new_findings.length().to_string(),
  )
  output.write_string(
    ", existing: " + report.existing_findings.length().to_string(),
  )
  output.write_string(", suppressed: " + report.suppressed.length().to_string())
  output.write_string(
    ", resolved: " + report.resolved_fingerprints.length().to_string(),
  )
  output.write_string(
    ", notices: " + report.notices.length().to_string() + "\n",
  )
  for finding in report.new_findings {
    write_terminal_finding(output, "NEW", finding)
  }
  for finding in report.existing_findings {
    write_terminal_finding(output, "EXISTING", finding)
  }
  for value in report.suppressed {
    output.write_string(
      "SUPPRESSED " +
      flatten_report_controls(value.violation.rule_id) +
      ": " +
      flatten_report_controls(value.reason) +
      " (owner=" +
      flatten_report_controls(value.owner) +
      ", expires=" +
      flatten_report_controls(value.expires) +
      ")\n",
    )
    write_path(output, value.violation.path)
  }
  for notice in report.notices {
    let kind = match notice.kind {
      @exception.ExpiredException => "ERROR expired exception"
      @exception.UnusedException => "WARNING unused exception"
    }
    output.write_string(
      kind +
      " " +
      flatten_report_controls(notice.rule_id) +
      " " +
      flatten_report_controls(notice.source) +
      " -> " +
      flatten_report_controls(notice.target) +
      ": " +
      flatten_report_controls(notice.message) +
      "\n",
    )
  }
  output.to_string()
}

///|
fn write_terminal_finding(
  output : StringBuilder,
  status : String,
  finding : @policy.Violation,
) -> Unit {
  output.write_string(
    status +
    " " +
    flatten_report_controls(finding.rule_id) +
    " [" +
    flatten_report_controls(finding.context.as_string()) +
    "]: " +
    flatten_report_controls(finding.source) +
    " -> " +
    flatten_report_controls(finding.target) +
    "\n",
  )
  write_path(output, finding.path)
}

///|
fn write_path(output : StringBuilder, path : Array[@graph.Edge]) -> Unit {
  if !path.is_empty() {
    let steps = path.map(edge => {
      flatten_report_controls(edge.source()) +
      " -> " +
      flatten_report_controls(edge.target()) +
      " (" +
      flatten_report_controls(edge.kind().as_string()) +
      ")"
    })
    output.write_string("  witness: " + steps.join("; ") + "\n")
  }
}
