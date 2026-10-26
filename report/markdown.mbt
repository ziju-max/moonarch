///|
pub fn render_markdown(report : Report) -> String {
  let output = StringBuilder()
  output.write_string("# MoonArch report\n\n")
  output.write_string("- Input: " + markdown_code_span(report.input) + "\n")
  output.write_string("- Date: " + markdown_code_span(report.today) + "\n")
  let baseline_text = if report.baseline_enabled {
    "enabled"
  } else {
    "disabled"
  }
  output.write_string("- Baseline: " + baseline_text + "\n")
  output.write_string(
    "- Counts: new " + report.new_findings.length().to_string(),
  )
  output.write_string(
    ", existing " + report.existing_findings.length().to_string(),
  )
  output.write_string(", suppressed " + report.suppressed.length().to_string())
  output.write_string(
    ", resolved " + report.resolved_fingerprints.length().to_string(),
  )
  output.write_string(
    ", notices " + report.notices.length().to_string() + "\n\n",
  )
  output.write_string("## New findings\n\n")
  write_markdown_findings(output, report.new_findings)
  output.write_string("## Existing findings\n\n")
  write_markdown_findings(output, report.existing_findings)
  output.write_string("## Suppressed findings\n\n")
  for value in report.suppressed {
    write_markdown_finding(output, value.violation)
    output.write_string(
      "  - Exception: " +
      markdown_text(value.reason) +
      " (owner " +
      markdown_code_span(value.owner) +
      ", expires " +
      markdown_code_span(value.expires) +
      ")\n\n",
    )
  }
  output.write_string("## Resolved fingerprints\n\n")
  for value in report.resolved_fingerprints {
    output.write_string("- " + markdown_code_span(value) + "\n")
  }
  if report.resolved_fingerprints.is_empty() {
    output.write_string("- None\n")
  }
  output.write_string("\n## Notices\n\n")
  for notice in report.notices {
    let kind = match notice.kind {
      @exception.ExpiredException => "Expired exception"
      @exception.UnusedException => "Unused exception"
    }
    output.write_string(
      "- **" +
      kind +
      "** " +
      markdown_code_span(notice.rule_id) +
      " " +
      markdown_code_span(notice.source) +
      " → " +
      markdown_code_span(notice.target) +
      ": " +
      markdown_text(notice.message) +
      "\n",
    )
  }
  if report.notices.is_empty() {
    output.write_string("- None\n")
  }
  output.to_string()
}

///|
fn write_markdown_findings(
  output : StringBuilder,
  findings : Array[@policy.Violation],
) -> Unit {
  for finding in findings {
    write_markdown_finding(output, finding)
  }
  if findings.is_empty() {
    output.write_string("- None\n\n")
  }
}

///|
fn write_markdown_finding(
  output : StringBuilder,
  finding : @policy.Violation,
) -> Unit {
  output.write_string(
    "- **" +
    markdown_code_span(finding.rule_id) +
    "** [" +
    markdown_text(finding.context.as_string()) +
    "] " +
    markdown_code_span(finding.source) +
    " → " +
    markdown_code_span(finding.target) +
    "\n",
  )
  if !finding.path.is_empty() {
    output.write_string(
      "  - Witness: " + markdown_code_span(path_nodes(finding.path)) + "\n",
    )
  }
}

///|
fn path_nodes(path : Array[@graph.Edge]) -> String {
  let nodes : Array[String] = [path[0].source()]
  for edge in path {
    nodes.push(edge.target())
  }
  nodes.join(" -> ")
}

///|
fn markdown_code_span(value : String) -> String {
  let safe = sanitize_terminal_text(value)
  let mut longest_run = 0
  let mut current_run = 0
  for character in safe.to_array() {
    if character == '`' {
      current_run = current_run + 1
      if current_run > longest_run {
        longest_run = current_run
      }
    } else {
      current_run = 0
    }
  }
  let delimiter = String::make(longest_run + 1, '`')
  delimiter + safe + delimiter
}

///|
fn markdown_text(value : String) -> String {
  let safe = sanitize_terminal_text(value)
  let pieces = safe
    .to_array()
    .map(character => {
      if character == '&' {
        "&amp;"
      } else if is_markdown_punctuation(character) {
        "\\" + character.to_string()
      } else {
        character.to_string()
      }
    })
  pieces.join("")
}

///|
fn is_markdown_punctuation(character : Char) -> Bool {
  match character {
    '\\'
    | '`'
    | '*'
    | '_'
    | '{'
    | '}'
    | '['
    | ']'
    | '('
    | ')'
    | '#'
    | '+'
    | '-'
    | '.'
    | '!'
    | '|'
    | '~'
    | '<'
    | '>' => true
    _ => false
  }
}
