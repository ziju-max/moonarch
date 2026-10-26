///|
pub(all) struct Report {
  schema_version : Int32
  input : String
  today : String
  baseline_enabled : Bool
  new_findings : Array[@policy.Violation]
  existing_findings : Array[@policy.Violation]
  suppressed : Array[@exception.SuppressedFinding]
  resolved_fingerprints : Array[String]
  notices : Array[@exception.ExceptionNotice]
  policy_warnings : Array[@policy.PolicyWarning]
}

///|
pub fn Report::has_new_failures(self : Report) -> Bool {
  !self.new_findings.is_empty() ||
  self.notices.iter().any(notice => notice.kind == @exception.ExpiredException)
}
