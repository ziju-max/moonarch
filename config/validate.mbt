///|
pub fn validate_config(config : Config) -> Unit raise ConfigError {
  if config.schema_version != 1 {
    raise ConfigError::InvalidValue(
      path="$.schema_version",
      detail="only schema version 1 is supported",
    )
  }
  if config.scope.includes.is_empty() {
    raise ConfigError::InvalidValue(
      path="$.scope.include",
      detail="at least one include selector is required",
    )
  }
  validate_patterns(config.scope.includes, "$.scope.include")
  validate_patterns(config.scope.exclude, "$.scope.exclude")

  let group_ids : Array[String] = []
  for index in 0..<config.groups.length() {
    let group = config.groups[index]
    let path = index_path("$.groups", index)
    require_nonempty(group.id, path + ".id")
    add_unique_id(group_ids, group.id)
    if group.packages.is_empty() {
      raise ConfigError::InvalidValue(
        path=path + ".packages",
        detail="at least one package selector is required",
      )
    }
    validate_patterns(group.packages, path + ".packages")
  }

  let layer_ids : Array[String] = []
  let layer_levels : Array[Int32] = []
  for index in 0..<config.layers.length() {
    let layer = config.layers[index]
    let path = index_path("$.layers", index)
    require_nonempty(layer.id, path + ".id")
    add_unique_id(layer_ids, layer.id)
    if layer.level < 0 {
      raise ConfigError::InvalidValue(
        path=path + ".level",
        detail="layer level must be non-negative",
      )
    }
    if layer.packages.is_empty() {
      raise ConfigError::InvalidValue(
        path=path + ".packages",
        detail="at least one package selector is required",
      )
    }
    validate_patterns(layer.packages, path + ".packages")
    if layer_levels.contains(layer.level) {
      raise ConfigError::InvalidValue(
        path=path + ".level",
        detail="layer levels must be unique",
      )
    }
    layer_levels.push(layer.level)
  }
  layer_levels.sort()
  for index in 0..<layer_levels.length() {
    if layer_levels[index] != index {
      raise ConfigError::InvalidValue(
        path="$.layers",
        detail="layer levels must be contiguous from zero",
      )
    }
  }

  let rule_ids : Array[String] = []
  let mut has_layer_rule = false
  for index in 0..<config.rules.length() {
    let rule = config.rules[index]
    let path = index_path("$.rules", index)
    let id = rule.id()
    require_nonempty(id, path + ".id")
    add_unique_id(rule_ids, id)
    match rule {
      Deny(value) => {
        validate_contexts(value.contexts, path + ".contexts")
        validate_group_refs(value.from, group_ids, path + ".from")
        validate_group_refs(value.to, group_ids, path + ".to")
        if value.from.is_empty() || value.to.is_empty() {
          raise ConfigError::InvalidValue(
            path~,
            detail="deny requires non-empty from and to groups",
          )
        }
      }
      AllowOnly(value) => {
        validate_contexts(value.contexts, path + ".contexts")
        validate_group_refs(value.from, group_ids, path + ".from")
        validate_group_refs(value.allow, group_ids, path + ".allow")
        if value.from.is_empty() || value.allow.is_empty() {
          raise ConfigError::InvalidValue(
            path~,
            detail="allow_only requires non-empty from and allow groups",
          )
        }
      }
      LayerDirection(value) => {
        has_layer_rule = true
        validate_contexts(value.contexts, path + ".contexts")
      }
      MaxLayerJump(value) => {
        has_layer_rule = true
        validate_contexts(value.contexts, path + ".contexts")
        if value.max < 0 {
          raise ConfigError::InvalidValue(
            path=path + ".max",
            detail="maximum layer jump must be non-negative",
          )
        }
      }
    }
  }
  if has_layer_rule && config.layers.is_empty() {
    raise ConfigError::InvalidValue(
      path="$.layers",
      detail="layer rules require at least one layer",
    )
  }

  for index in 0..<config.exceptions.length() {
    let exception = config.exceptions[index]
    let path = index_path("$.exceptions", index)
    require_nonempty(exception.rule_id, path + ".rule_id")
    require_nonempty(exception.source, path + ".source")
    require_nonempty(exception.target, path + ".target")
    require_nonempty(exception.reason, path + ".reason")
    require_nonempty(exception.owner, path + ".owner")
    if !rule_ids.contains(exception.rule_id) {
      raise ConfigError::InvalidValue(
        path=path + ".rule_id",
        detail="exception references an unknown rule",
      )
    }
    if !valid_iso_date(exception.expires) {
      raise ConfigError::InvalidDate(
        path=path + ".expires",
        value=exception.expires,
      )
    }
  }
  match config.baseline {
    Some(path) if path.trim().is_empty() =>
      raise ConfigError::InvalidValue(
        path="$.baseline",
        detail="baseline path cannot be empty",
      )
    _ => ()
  }
}

///|
fn validate_patterns(
  patterns : Array[String],
  path : String,
) -> Unit raise ConfigError {
  for index in 0..<patterns.length() {
    if !@selector.validate_pattern(patterns[index]) {
      raise ConfigError::InvalidValue(
        path=index_path(path, index),
        detail="malformed package selector",
      )
    }
  }
}

///|
fn validate_contexts(
  contexts : Array[@graph.Context],
  path : String,
) -> Unit raise ConfigError {
  if contexts.is_empty() {
    raise ConfigError::InvalidValue(
      path~,
      detail="at least one context is required",
    )
  }
  for left in 0..<contexts.length() {
    for right in (left + 1)..<contexts.length() {
      if contexts[left] == contexts[right] {
        raise ConfigError::DuplicateContext(
          path~,
          context=contexts[left].as_string(),
        )
      }
    }
  }
}

///|
fn validate_group_refs(
  ids : Array[String],
  known : Array[String],
  path : String,
) -> Unit raise ConfigError {
  for index in 0..<ids.length() {
    if !known.contains(ids[index]) {
      raise ConfigError::UnknownGroup(
        path=index_path(path, index),
        id=ids[index],
      )
    }
  }
}

///|
fn add_unique_id(known : Array[String], id : String) -> Unit raise ConfigError {
  if known.contains(id) {
    raise ConfigError::DuplicateId(id~)
  }
  known.push(id)
}

///|
fn require_nonempty(value : String, path : String) -> Unit raise ConfigError {
  if value.trim().is_empty() {
    raise ConfigError::InvalidValue(path~, detail="value cannot be empty")
  }
}

///|
fn valid_iso_date(value : String) -> Bool {
  let chars = value.to_array()
  if chars.length() != 10 || chars[4] != '-' || chars[7] != '-' {
    return false
  }
  for index in 0..<chars.length() {
    if index != 4 && index != 7 && (chars[index] < '0' || chars[index] > '9') {
      return false
    }
  }
  let year = decimal_pair(chars[0], chars[1]) * 100 +
    decimal_pair(chars[2], chars[3])
  let month = decimal_pair(chars[5], chars[6])
  let day = decimal_pair(chars[8], chars[9])
  if year == 0 || month < 1 || month > 12 || day < 1 {
    return false
  }
  let max_day = match month {
    2 =>
      if year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) {
        29
      } else {
        28
      }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
  day <= max_day
}

///|
fn decimal_pair(tens : Char, ones : Char) -> Int32 {
  (tens.to_int() - 48) * 10 + ones.to_int() - 48
}
