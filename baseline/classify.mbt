///|
pub fn classify(
  current : Array[@policy.Violation],
  baseline : Baseline,
) -> BaselineResult {
  let new_findings : Array[@policy.Violation] = []
  let existing_findings : Array[@policy.Violation] = []
  let current_fingerprints : Array[String] = []
  for finding in current {
    let value = fingerprint(finding)
    if !current_fingerprints.contains(value) {
      current_fingerprints.push(value)
      if baseline.fingerprints.contains(value) {
        existing_findings.push(finding)
      } else {
        new_findings.push(finding)
      }
    }
  }
  let resolved : Array[String] = []
  for value in baseline.fingerprints {
    if !current_fingerprints.contains(value) {
      resolved.push(value)
    }
  }
  { new_findings, existing_findings, resolved_fingerprints: resolved, }
}
