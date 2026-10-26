///|
pub fn evaluate(
  graph : @graph.Graph,
  config : @config.Config,
) -> Array[Violation] raise PolicyError {
  let needs_layers = config.rules
    .iter()
    .any(rule => {
      match rule {
        @config.LayerDirection(_) | @config.MaxLayerJump(_) => true
        _ => false
      }
    })
  if needs_layers {
    validate_layer_coverage(graph, config)
  }
  let findings : Array[Violation] = []
  for rule in config.rules {
    match rule {
      @config.Deny(value) => evaluate_deny(graph, config, value, findings)
      @config.AllowOnly(value) =>
        evaluate_allow_only(graph, config, value, findings)
      @config.LayerDirection(value) =>
        evaluate_layer_direction(graph, config, value, findings)
      @config.MaxLayerJump(value) =>
        evaluate_max_jump(graph, config, value, findings)
    }
  }
  findings.sort_by(violation_order)
  findings
}

///|
fn evaluate_deny(
  graph : @graph.Graph,
  config : @config.Config,
  rule : @config.DenyRule,
  findings : Array[Violation],
) -> Unit {
  let sources = group_members(graph, config, rule.from)
  let targets = group_members(graph, config, rule.to)
  for context in rule.contexts {
    for source in sources {
      for target in targets {
        if source != target {
          let path = if rule.transitive {
            @witness.find_path(graph, source, target, context)
          } else {
            direct_path(graph, source, target, context)
          }
          match path {
            Some(witness) if !witness.is_empty() =>
              add_finding(findings, {
                rule_id: rule.id,
                source,
                target,
                context,
                path: witness,
              })
            _ => ()
          }
        }
      }
    }
  }
}

///|
fn evaluate_allow_only(
  graph : @graph.Graph,
  config : @config.Config,
  rule : @config.AllowOnlyRule,
  findings : Array[Violation],
) -> Unit {
  let sources = group_members(graph, config, rule.from)
  let allowed = group_members(graph, config, rule.allow)
  for context in rule.contexts {
    for source in sources {
      for edge in graph.outgoing(source, context) {
        if is_in_scope(config, edge.target()) &&
          !allowed.contains(edge.target()) {
          add_finding(findings, {
            rule_id: rule.id,
            source,
            target: edge.target(),
            context,
            path: [edge],
          })
        }
      }
    }
  }
}

///|
fn evaluate_layer_direction(
  graph : @graph.Graph,
  config : @config.Config,
  rule : @config.LayerDirectionRule,
  findings : Array[Violation],
) -> Unit raise PolicyError {
  for context in rule.contexts {
    for edge in graph.edges() {
      if is_in_scope(config, edge.source()) &&
        is_in_scope(config, edge.target()) &&
        context.allows(edge.kind()) {
        let source_level = layer_level(config, edge.source())
        let target_level = layer_level(config, edge.target())
        if source_level < target_level {
          add_finding(findings, {
            rule_id: rule.id,
            source: edge.source(),
            target: edge.target(),
            context,
            path: [edge],
          })
        }
      }
    }
  }
}

///|
fn evaluate_max_jump(
  graph : @graph.Graph,
  config : @config.Config,
  rule : @config.MaxLayerJumpRule,
  findings : Array[Violation],
) -> Unit raise PolicyError {
  for context in rule.contexts {
    for edge in graph.edges() {
      if is_in_scope(config, edge.source()) &&
        is_in_scope(config, edge.target()) &&
        context.allows(edge.kind()) {
        let source_level = layer_level(config, edge.source())
        let target_level = layer_level(config, edge.target())
        if source_level >= target_level &&
          source_level - target_level > rule.max {
          add_finding(findings, {
            rule_id: rule.id,
            source: edge.source(),
            target: edge.target(),
            context,
            path: [edge],
          })
        }
      }
    }
  }
}

///|
fn direct_path(
  graph : @graph.Graph,
  source : String,
  target : String,
  context : @graph.Context,
) -> Array[@graph.Edge]? {
  for edge in graph.outgoing(source, context) {
    if edge.target() == target {
      return Some([edge])
    }
  }
  None
}

///|
fn group_members(
  graph : @graph.Graph,
  config : @config.Config,
  group_ids : Array[String],
) -> Array[String] {
  let packages = graph.packages()
  let members : Array[String] = []
  for package_name in packages {
    if is_in_scope(config, package_name) &&
      package_matches_groups(config, group_ids, package_name) {
      members.push(package_name)
    }
  }
  members
}

///|
fn package_matches_groups(
  config : @config.Config,
  group_ids : Array[String],
  package_name : String,
) -> Bool {
  for group in config.groups {
    if group_ids.contains(group.id) {
      for pattern in group.packages {
        if @selector.matches(pattern, package_name) {
          return true
        }
      }
    }
  }
  false
}

///|
fn is_in_scope(config : @config.Config, package_name : String) -> Bool {
  let included = config.scope.includes
    .iter()
    .any(pattern => @selector.matches(pattern, package_name))
  if !included {
    return false
  }
  !config.scope.exclude
  .iter()
  .any(pattern => @selector.matches(pattern, package_name))
}

///|
fn layer_level(
  config : @config.Config,
  package_name : String,
) -> Int32 raise PolicyError {
  let mut found : Int32? = None
  for layer in config.layers {
    if layer.packages
      .iter()
      .any(pattern => @selector.matches(pattern, package_name)) {
      match found {
        Some(_) => raise PolicyError::OverlappingLayers(package_name)
        None => found = Some(layer.level)
      }
    }
  }
  match found {
    Some(level) => level
    None => raise PolicyError::MissingLayer(package_name)
  }
}

///|
fn validate_layer_coverage(
  graph : @graph.Graph,
  config : @config.Config,
) -> Unit raise PolicyError {
  for package_name in graph.packages() {
    if is_in_scope(config, package_name) {
      layer_level(config, package_name) |> ignore
    }
  }
}

///|
fn add_finding(findings : Array[Violation], finding : Violation) -> Unit {
  if !findings.iter().any(existing => same_finding(existing, finding)) {
    findings.push(finding)
  }
}

///|
fn same_finding(left : Violation, right : Violation) -> Bool {
  left.rule_id == right.rule_id &&
  left.source == right.source &&
  left.target == right.target &&
  left.context == right.context
}

///|
fn violation_order(left : Violation, right : Violation) -> Int32 {
  let rule_order = text_order(left.rule_id, right.rule_id)
  if rule_order != 0 {
    return rule_order
  }
  let source_order = text_order(left.source, right.source)
  if source_order != 0 {
    return source_order
  }
  let target_order = text_order(left.target, right.target)
  if target_order != 0 {
    return target_order
  }
  text_order(left.context.as_string(), right.context.as_string())
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
