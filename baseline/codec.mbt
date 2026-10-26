///|
pub fn fingerprint(violation : @policy.Violation) -> String {
  let fields = [
    violation.rule_id,
    violation.source,
    violation.target,
    violation.context.as_string(),
  ]
  let encoded : Array[String] = []
  for field in fields {
    encoded.push(field.length().to_string() + ":" + field)
  }
  "v1:" + encoded.join(":")
}

///|
pub fn serialize_baseline(baseline : Baseline) -> String {
  let encoded : Array[String] = []
  for value in baseline.fingerprints {
    encoded.push(@json.to_json(value).stringify())
  }
  "{\n  \"schema_version\": 1,\n  \"fingerprints\": [" +
  encoded.join(", ") +
  "]\n}\n"
}

///|
pub fn parse_baseline(text : String) -> Baseline raise BaselineError {
  let value = @json.parse(text, reject_duplicate_keys=true) catch {
    _ => raise BaselineError::InvalidJson
  }
  let object = match value {
    Object(fields) => fields
    _ => raise BaselineError::InvalidShape("$")
  }
  for key in object.keys() {
    if key != "schema_version" && key != "fingerprints" {
      raise BaselineError::UnknownField("$." + key)
    }
  }
  let version = match object.get("schema_version") {
    Some(Number(_, ..) as number) =>
      @json.from_json(number) catch {
        _ => raise BaselineError::InvalidShape("$.schema_version")
      }
    _ => raise BaselineError::InvalidShape("$.schema_version")
  }
  if version != 1 {
    raise BaselineError::UnsupportedVersion(version)
  }
  let values = match object.get("fingerprints") {
    Some(Array(values)) => values
    _ => raise BaselineError::InvalidShape("$.fingerprints")
  }
  let fingerprints : Array[String] = []
  for index in 0..<values.length() {
    match values[index] {
      String(value) => {
        if fingerprints.contains(value) {
          raise BaselineError::DuplicateFingerprint(value)
        }
        fingerprints.push(value)
      }
      _ =>
        raise BaselineError::InvalidShape(
          "$.fingerprints[" + index.to_string() + "]",
        )
    }
  }
  Baseline::from_fingerprints(fingerprints)
}
