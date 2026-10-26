///|
pub(all) suberror OfflineGraphError {
  InvalidJson
  InvalidShape(String)
  UnknownField(path~ : String)
  UnsupportedVersion(Int32)
  InvalidEdgeKind(String)
  InvalidGraph
}

///|
pub fn parse_offline_json(text : String) -> Graph raise OfflineGraphError {
  let root = @json.parse(text, reject_duplicate_keys=true) catch {
    _ => raise OfflineGraphError::InvalidJson
  }
  let object = object_value(root, "$")
  reject_fields(object, ["schema_version", "packages", "edges"], "$")
  let version = integer_field(object, "schema_version", "$")
  if version != 1 {
    raise OfflineGraphError::UnsupportedVersion(version)
  }
  let packages = string_array_field(object, "packages", "$")
  let edge_values = array_field(object, "edges", "$")
  let edges : Array[Edge] = []
  for index in 0..<edge_values.length() {
    let path = "$.edges[" + index.to_string() + "]"
    let edge = object_value(edge_values[index], path)
    reject_fields(edge, ["source", "target", "kind"], path)
    let source = string_field(edge, "source", path)
    let target = string_field(edge, "target", path)
    let kind_name = string_field(edge, "kind", path)
    let kind = match kind_name {
      "normal" => Normal
      "test" => Test
      "wbtest" => Wbtest
      _ => raise OfflineGraphError::InvalidEdgeKind(kind_name)
    }
    edges.push(Edge::new(source~, target~, kind~))
  }
  normalize(packages, edges) catch {
    _ => raise OfflineGraphError::InvalidGraph
  }
}

///|
fn object_value(
  value : Json,
  path : String,
) -> Map[String, Json] raise OfflineGraphError {
  match value {
    Object(fields) => fields
    _ => raise OfflineGraphError::InvalidShape(path)
  }
}

///|
fn array_field(
  object : Map[String, Json],
  name : String,
  path : String,
) -> Array[Json] raise OfflineGraphError {
  match object.get(name) {
    Some(Array(values)) => values
    _ => raise OfflineGraphError::InvalidShape(path + "." + name)
  }
}

///|
fn string_field(
  object : Map[String, Json],
  name : String,
  path : String,
) -> String raise OfflineGraphError {
  match object.get(name) {
    Some(String(value)) => value
    _ => raise OfflineGraphError::InvalidShape(path + "." + name)
  }
}

///|
fn integer_field(
  object : Map[String, Json],
  name : String,
  path : String,
) -> Int32 raise OfflineGraphError {
  match object.get(name) {
    Some(Number(_, ..) as value) =>
      @json.from_json(value) catch {
        _ => raise OfflineGraphError::InvalidShape(path + "." + name)
      }
    _ => raise OfflineGraphError::InvalidShape(path + "." + name)
  }
}

///|
fn string_array_field(
  object : Map[String, Json],
  name : String,
  path : String,
) -> Array[String] raise OfflineGraphError {
  let values = array_field(object, name, path)
  let result : Array[String] = []
  for index in 0..<values.length() {
    match values[index] {
      String(value) => result.push(value)
      _ =>
        raise OfflineGraphError::InvalidShape(
          path + "." + name + "[" + index.to_string() + "]",
        )
    }
  }
  result
}

///|
fn reject_fields(
  object : Map[String, Json],
  allowed : Array[String],
  path : String,
) -> Unit raise OfflineGraphError {
  for key in object.keys() {
    if !allowed.contains(key) {
      raise OfflineGraphError::UnknownField(path=path + "." + key)
    }
  }
}
