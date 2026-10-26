///|
pub(all) struct Baseline {
  schema_version : Int32
  fingerprints : Array[String]
}

///|
pub fn Baseline::from_fingerprints(fingerprints : Array[String]) -> Baseline {
  let sorted = fingerprints.copy()
  sorted.sort_by(text_order)
  let unique : Array[String] = []
  for value in sorted {
    if unique.is_empty() || unique[unique.length() - 1] != value {
      unique.push(value)
    }
  }
  { schema_version: 1, fingerprints: unique, }
}

///|
pub(all) struct BaselineResult {
  new_findings : Array[@policy.Violation]
  existing_findings : Array[@policy.Violation]
  resolved_fingerprints : Array[String]
}

///|
pub(all) suberror BaselineError {
  InvalidJson
  InvalidShape(String)
  UnknownField(String)
  UnsupportedVersion(Int32)
  DuplicateFingerprint(String)
}

///|
fn text_order(left : String, right : String) -> Int32 {
  let left_chars = left.to_array()
  let right_chars = right.to_array()
  let limit = if left_chars.length() < right_chars.length() {
    left_chars.length()
  } else {
    right_chars.length()
  }
  for index in 0..<limit {
    let left_code = left_chars[index].to_int()
    let right_code = right_chars[index].to_int()
    if left_code < right_code {
      return -1
    }
    if left_code > right_code {
      return 1
    }
  }
  if left_chars.length() < right_chars.length() {
    -1
  } else if left_chars.length() > right_chars.length() {
    1
  } else {
    0
  }
}
