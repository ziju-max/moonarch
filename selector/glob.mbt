///|
pub(all) suberror SelectorError {
  EmptyPattern
  MalformedPattern(String)
}

///|
pub fn matches(pattern : String, package_name : String) -> Bool {
  if !validate_pattern(pattern) || !valid_package_name(package_name) {
    return false
  }
  let pattern_segments = split_segments(pattern)
  let package_segments = split_segments(package_name)
  path_segments_match(pattern_segments, package_segments)
}

///|
pub fn expand(
  patterns : Array[String],
  packages : Array[String],
) -> Array[String] raise SelectorError {
  let expanded : Array[String] = []
  for pattern in patterns {
    if pattern.is_empty() {
      raise SelectorError::EmptyPattern
    }
    if !validate_pattern(pattern) {
      raise SelectorError::MalformedPattern(pattern)
    }
    for package_name in packages {
      if matches(pattern, package_name) && !expanded.contains(package_name) {
        expanded.push(package_name)
      }
    }
  }
  expanded.sort_by(text_order)
  expanded
}

///|
fn valid_package_name(package_name : String) -> Bool {
  if package_name.is_empty() ||
    package_name.has_prefix("/") ||
    package_name.has_suffix("/") {
    return false
  }
  if package_name.contains("//") ||
    package_name.contains_char('\\') ||
    package_name.contains_char('*') {
    return false
  }
  true
}

///|
pub fn validate_pattern(pattern : String) -> Bool {
  if pattern.is_empty() || pattern.has_prefix("/") || pattern.has_suffix("/") {
    return false
  }
  if pattern.contains("//") || pattern.contains_char('\\') {
    return false
  }
  for segment in split_segments(pattern) {
    if segment.contains("**") && segment != "**" {
      return false
    }
    if segment.contains("***") {
      return false
    }
  }
  true
}

///|
fn split_segments(path : String) -> Array[String] {
  path.split("/").map(segment => segment.to_owned()).to_array()
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

///|
fn path_segments_match(
  patterns : Array[String],
  values : Array[String],
) -> Bool {
  let mut pattern_index = 0
  let mut value_index = 0
  let mut last_recursive = -1
  let mut last_recursive_value = 0
  while value_index < values.length() {
    if pattern_index < patterns.length() && patterns[pattern_index] == "**" {
      last_recursive = pattern_index
      pattern_index = pattern_index + 1
      last_recursive_value = value_index
    } else if pattern_index < patterns.length() &&
      segment_matches(patterns[pattern_index], values[value_index]) {
      pattern_index = pattern_index + 1
      value_index = value_index + 1
    } else if last_recursive >= 0 {
      last_recursive_value = last_recursive_value + 1
      value_index = last_recursive_value
      pattern_index = last_recursive + 1
    } else {
      return false
    }
  }
  while pattern_index < patterns.length() && patterns[pattern_index] == "**" {
    pattern_index = pattern_index + 1
  }
  pattern_index == patterns.length()
}

///|
fn segment_matches(pattern : String, value : String) -> Bool {
  let pattern_chars = pattern.to_array()
  let value_chars = value.to_array()
  let mut pattern_index = 0
  let mut value_index = 0
  let mut last_star = -1
  let mut last_star_value = 0
  while value_index < value_chars.length() {
    if pattern_index < pattern_chars.length() &&
      pattern_chars[pattern_index] == value_chars[value_index] {
      pattern_index = pattern_index + 1
      value_index = value_index + 1
    } else if pattern_index < pattern_chars.length() &&
      pattern_chars[pattern_index] == '*' {
      last_star = pattern_index
      pattern_index = pattern_index + 1
      last_star_value = value_index
    } else if last_star >= 0 {
      last_star_value = last_star_value + 1
      value_index = last_star_value
      pattern_index = last_star + 1
    } else {
      return false
    }
  }
  while pattern_index < pattern_chars.length() &&
        pattern_chars[pattern_index] == '*' {
    pattern_index = pattern_index + 1
  }
  pattern_index == pattern_chars.length()
}
