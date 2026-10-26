///|
pub(all) enum NoticeKind {
  ExpiredException
  UnusedException
} derive(Eq)

///|
pub extend NoticeKind with Eq::{equal, not_equal}

///|
pub(all) struct SuppressedFinding {
  violation : @policy.Violation
  reason : String
  owner : String
  expires : String
}

///|
pub(all) struct ExceptionNotice {
  kind : NoticeKind
  rule_id : String
  source : String
  target : String
  message : String
}

///|
pub(all) struct ExceptionResult {
  visible : Array[@policy.Violation]
  suppressed : Array[SuppressedFinding]
  notices : Array[ExceptionNotice]
}

///|
pub(all) suberror ExceptionError {
  InvalidToday(String)
  DuplicateMatch(String)
}

///|
pub fn apply_exceptions(
  findings : Array[@policy.Violation],
  exceptions : Array[@config.Exception],
  today : String,
) -> ExceptionResult raise ExceptionError {
  if !valid_date_shape(today) {
    raise ExceptionError::InvalidToday(today)
  }
  let matched = Array::make(exceptions.length(), false)
  let visible : Array[@policy.Violation] = []
  let suppressed : Array[SuppressedFinding] = []
  let notices : Array[ExceptionNotice] = []
  for finding in findings {
    let mut matching : Int32? = None
    for index in 0..<exceptions.length() {
      if exact_match(finding, exceptions[index]) {
        match matching {
          Some(_) => raise ExceptionError::DuplicateMatch(finding.rule_id)
          None => matching = Some(index)
        }
      }
    }
    match matching {
      None => visible.push(finding)
      Some(index) => {
        matched[index] = true
        let exception = exceptions[index]
        if date_order(exception.expires, today) < 0 {
          visible.push(finding)
          notices.push({
            kind: ExpiredException,
            rule_id: exception.rule_id,
            source: exception.source,
            target: exception.target,
            message: "exception expired on " + exception.expires,
          })
        } else {
          suppressed.push({
            violation: finding,
            reason: exception.reason,
            owner: exception.owner,
            expires: exception.expires,
          })
        }
      }
    }
  }
  for index in 0..<exceptions.length() {
    if !matched[index] {
      let exception = exceptions[index]
      notices.push({
        kind: UnusedException,
        rule_id: exception.rule_id,
        source: exception.source,
        target: exception.target,
        message: "exception does not match a current finding",
      })
    }
  }
  { visible, suppressed, notices, }
}

///|
fn exact_match(
  finding : @policy.Violation,
  exception : @config.Exception,
) -> Bool {
  finding.rule_id == exception.rule_id &&
  finding.source == exception.source &&
  finding.target == exception.target &&
  finding.context == exception.context
}

///|
fn valid_date_shape(value : String) -> Bool {
  let chars = value.to_array()
  if chars.length() != 10 || chars[4] != '-' || chars[7] != '-' {
    return false
  }
  for index in 0..<chars.length() {
    if index != 4 && index != 7 && (chars[index] < '0' || chars[index] > '9') {
      return false
    }
  }
  true
}

///|
fn date_order(left : String, right : String) -> Int32 {
  let left_chars = left.to_array()
  let right_chars = right.to_array()
  for index in 0..<10 {
    let left_code = left_chars[index].to_int()
    let right_code = right_chars[index].to_int()
    if left_code < right_code {
      return -1
    }
    if left_code > right_code {
      return 1
    }
  }
  0
}
