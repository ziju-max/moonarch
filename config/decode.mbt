///|
pub fn parse_config(text : String) -> Config raise ConfigError {
  let value = @json.parse(text, reject_duplicate_keys=true) catch {
    _ => raise ConfigError::InvalidJson("$")
  }
  let object = object_value(value, "$")
  reject_unknown(
    object,
    [
      "schema_version", "scope", "groups", "layers", "rules", "exceptions", "baseline",
    ],
    "$",
  )
  let schema_version = int_field(object, "schema_version", "$")
  let scope = parse_scope(required(object, "scope", "$").0, "$.scope")
  let groups = parse_groups(required(object, "groups", "$").0, "$.groups")
  let layers = match object.get("layers") {
    None => []
    Some(value) => parse_layers(value, "$.layers")
  }
  let rules = parse_rules(required(object, "rules", "$").0, "$.rules")
  let exceptions = match object.get("exceptions") {
    None => []
    Some(value) => parse_exceptions(value, "$.exceptions")
  }
  let baseline = match object.get("baseline") {
    None => None
    Some(value) => Some(string_value(value, "$.baseline"))
  }
  let config = {
    schema_version,
    scope,
    groups,
    layers,
    rules,
    exceptions,
    baseline,
  }
  validate_config(config)
  config
}

///|
fn parse_scope(value : Json, path : String) -> Scope raise ConfigError {
  let object = object_value(value, path)
  reject_unknown(object, ["include", "exclude"], path)
  let includes = string_array(
    required(object, "include", path).0,
    path + ".include",
  )
  let exclude = match object.get("exclude") {
    None => []
    Some(value) => string_array(value, path + ".exclude")
  }
  { includes, exclude, }
}

///|
fn parse_groups(value : Json, path : String) -> Array[Group] raise ConfigError {
  let groups = array_value(value, path)
  let output : Array[Group] = []
  for index in 0..<groups.length() {
    let item_path = index_path(path, index)
    let object = object_value(groups[index], item_path)
    reject_unknown(object, ["id", "packages"], item_path)
    let id = string_field(object, "id", item_path)
    let packages = string_array(
      required(object, "packages", item_path).0,
      item_path + ".packages",
    )
    output.push({ id, packages, })
  }
  output
}

///|
fn parse_layers(value : Json, path : String) -> Array[Layer] raise ConfigError {
  let layers = array_value(value, path)
  let output : Array[Layer] = []
  for index in 0..<layers.length() {
    let item_path = index_path(path, index)
    let object = object_value(layers[index], item_path)
    reject_unknown(object, ["id", "packages", "level"], item_path)
    let id = string_field(object, "id", item_path)
    let packages = string_array(
      required(object, "packages", item_path).0,
      item_path + ".packages",
    )
    let level = int_field(object, "level", item_path)
    output.push({ id, packages, level, })
  }
  output
}

///|
fn parse_rules(value : Json, path : String) -> Array[Rule] raise ConfigError {
  let rules = array_value(value, path)
  let output : Array[Rule] = []
  for index in 0..<rules.length() {
    let item_path = index_path(path, index)
    let object = object_value(rules[index], item_path)
    let id = string_field(object, "id", item_path)
    let kind = string_field(object, "type", item_path)
    match kind {
      "deny" => {
        reject_unknown(
          object,
          ["id", "type", "from", "to", "transitive", "contexts"],
          item_path,
        )
        let from = string_array(
          required(object, "from", item_path).0,
          item_path + ".from",
        )
        let to = string_array(
          required(object, "to", item_path).0,
          item_path + ".to",
        )
        let transitive = bool_field(object, "transitive", item_path)
        let contexts = context_array(
          required(object, "contexts", item_path).0,
          item_path + ".contexts",
        )
        output.push(Deny({ id, from, to, transitive, contexts, }))
      }
      "allow_only" => {
        reject_unknown(
          object,
          ["id", "type", "from", "allow", "contexts"],
          item_path,
        )
        let from = string_array(
          required(object, "from", item_path).0,
          item_path + ".from",
        )
        let allow = string_array(
          required(object, "allow", item_path).0,
          item_path + ".allow",
        )
        let contexts = context_array(
          required(object, "contexts", item_path).0,
          item_path + ".contexts",
        )
        output.push(AllowOnly({ id, from, allow, contexts, }))
      }
      "layer_direction" => {
        reject_unknown(object, ["id", "type", "contexts"], item_path)
        let contexts = context_array(
          required(object, "contexts", item_path).0,
          item_path + ".contexts",
        )
        output.push(LayerDirection({ id, contexts, }))
      }
      "max_layer_jump" => {
        reject_unknown(object, ["id", "type", "max", "contexts"], item_path)
        let max = int_field(object, "max", item_path)
        let contexts = context_array(
          required(object, "contexts", item_path).0,
          item_path + ".contexts",
        )
        output.push(MaxLayerJump({ id, max, contexts, }))
      }
      _ =>
        raise ConfigError::InvalidValue(
          path=item_path + ".type",
          detail="unsupported rule type",
        )
    }
  }
  output
}

///|
fn parse_exceptions(
  value : Json,
  path : String,
) -> Array[Exception] raise ConfigError {
  let exceptions = array_value(value, path)
  let output : Array[Exception] = []
  for index in 0..<exceptions.length() {
    let item_path = index_path(path, index)
    let object = object_value(exceptions[index], item_path)
    reject_unknown(
      object,
      ["rule_id", "source", "target", "context", "reason", "owner", "expires"],
      item_path,
    )
    let rule_id = string_field(object, "rule_id", item_path)
    let source = string_field(object, "source", item_path)
    let target = string_field(object, "target", item_path)
    let context = context_value(
      required(object, "context", item_path).0,
      item_path + ".context",
    )
    let reason = string_field(object, "reason", item_path)
    let owner = string_field(object, "owner", item_path)
    let expires = string_field(object, "expires", item_path)
    output.push({ rule_id, source, target, context, reason, owner, expires, })
  }
  output
}

///|
fn context_array(
  value : Json,
  path : String,
) -> Array[@graph.Context] raise ConfigError {
  let values = string_array(value, path)
  let contexts : Array[@graph.Context] = []
  for index in 0..<values.length() {
    let item_path = index_path(path, index)
    let context = parse_context(values[index], item_path)
    if contexts.contains(context) {
      raise ConfigError::DuplicateContext(path=item_path, context=values[index])
    }
    contexts.push(context)
  }
  contexts
}

///|
fn context_value(
  value : Json,
  path : String,
) -> @graph.Context raise ConfigError {
  parse_context(string_value(value, path), path)
}

///|
fn parse_context(
  value : String,
  path : String,
) -> @graph.Context raise ConfigError {
  match value {
    "normal" => @graph.NormalContext
    "test" => @graph.TestContext
    "wbtest" => @graph.WbtestContext
    _ =>
      raise ConfigError::InvalidValue(
        path~,
        detail="expected normal, test, or wbtest",
      )
  }
}

///|
fn object_value(
  value : Json,
  path : String,
) -> Map[String, Json] raise ConfigError {
  match value {
    Object(fields) => fields
    _ => raise ConfigError::ExpectedObject(path)
  }
}

///|
fn array_value(value : Json, path : String) -> Array[Json] raise ConfigError {
  match value {
    Array(items) => items
    _ => raise ConfigError::ExpectedArray(path)
  }
}

///|
fn required(
  object : Map[String, Json],
  name : String,
  path : String,
) -> (Json, Unit) raise ConfigError {
  match object.get(name) {
    Some(value) => (value, ())
    None => raise ConfigError::MissingField(path + "." + name)
  }
}

///|
fn string_field(
  object : Map[String, Json],
  name : String,
  path : String,
) -> String raise ConfigError {
  string_value(required(object, name, path).0, path + "." + name)
}

///|
fn int_field(
  object : Map[String, Json],
  name : String,
  path : String,
) -> Int32 raise ConfigError {
  let value = required(object, name, path).0
  match value {
    Number(_, ..) =>
      @json.from_json(value) catch {
        _ => raise ConfigError::TypeMismatch(path + "." + name)
      }
    _ => raise ConfigError::TypeMismatch(path + "." + name)
  }
}

///|
fn bool_field(
  object : Map[String, Json],
  name : String,
  path : String,
) -> Bool raise ConfigError {
  let value = required(object, name, path).0
  match value {
    True => true
    False => false
    _ => raise ConfigError::TypeMismatch(path + "." + name)
  }
}

///|
fn string_value(value : Json, path : String) -> String raise ConfigError {
  match value {
    String(text) => text
    _ => raise ConfigError::TypeMismatch(path)
  }
}

///|
fn string_array(value : Json, path : String) -> Array[String] raise ConfigError {
  let values = array_value(value, path)
  let output : Array[String] = []
  for index in 0..<values.length() {
    output.push(string_value(values[index], index_path(path, index)))
  }
  output
}

///|
fn reject_unknown(
  object : Map[String, Json],
  allowed : Array[String],
  path : String,
) -> Unit raise ConfigError {
  for key in object.keys() {
    if !allowed.contains(key) {
      raise ConfigError::UnknownField(path=path + "." + key)
    }
  }
}

///|
fn index_path(path : String, index : Int32) -> String {
  path + "[" + index.to_string() + "]"
}
