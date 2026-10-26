///|
pub fn render_terminal(report : Report) -> String {
  let status = if report.has_new_failures() { "FAIL" } else { "PASS" }
  let output = StringBuilder()
  output.write_string("MoonArch " + status + "\n")
  output.write_string("Input: " + sanitize_terminal_text(report.input) + "\n")
  output.write_string("Date: " + sanitize_terminal_text(report.today) + "\n")
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
  output.write_string(", notices: " + report.notices.length().to_string())
  output.write_string(
    ", policy warnings: " + report.policy_warnings.length().to_string() + "\n",
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
      sanitize_terminal_text(value.violation.rule_id) +
      ": " +
      sanitize_terminal_text(value.reason) +
      " (owner=" +
      sanitize_terminal_text(value.owner) +
      ", expires=" +
      sanitize_terminal_text(value.expires) +
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
      sanitize_terminal_text(notice.rule_id) +
      " " +
      sanitize_terminal_text(notice.source) +
      " -> " +
      sanitize_terminal_text(notice.target) +
      ": " +
      sanitize_terminal_text(notice.message) +
      "\n",
    )
  }
  for warning in report.policy_warnings {
    output.write_string(
      "WARNING unmatched group " +
      sanitize_terminal_text(warning.group_id) +
      ": " +
      sanitize_terminal_text(warning.message) +
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
    sanitize_terminal_text(finding.rule_id) +
    " [" +
    sanitize_terminal_text(finding.context.as_string()) +
    "]: " +
    sanitize_terminal_text(finding.source) +
    " -> " +
    sanitize_terminal_text(finding.target) +
    "\n",
  )
  write_path(output, finding.path)
}

///|
fn write_path(output : StringBuilder, path : Array[@graph.Edge]) -> Unit {
  if !path.is_empty() {
    let steps = path.map(edge => {
      sanitize_terminal_text(edge.source()) +
      " -> " +
      sanitize_terminal_text(edge.target()) +
      " (" +
      sanitize_terminal_text(edge.kind().as_string()) +
      ")"
    })
    output.write_string("  witness: " + steps.join("; ") + "\n")
  }
}
