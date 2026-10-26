///|
pub(all) suberror MoonTreeError {
  InvalidJson
  UnsupportedVersion(Int32)
  InvalidStatus(String)
  InvalidShape(String)
  InvalidEdgeKind(String)
  InvalidGraph
}

///|
pub fn parse_moon_tree_json(text : String) -> @graph.Graph raise MoonTreeError {
  let root = @json.parse(text, reject_duplicate_keys=true) catch {
    _ => raise MoonTreeError::InvalidJson
  }
  let object = as_object(root, "$")
  let version = int_property(object, "version", "$")
  if version != 3 {
    raise MoonTreeError::UnsupportedVersion(version)
  }
  let status = string_property(object, "status", "$")
  if status != "success" {
    raise MoonTreeError::InvalidStatus(status)
  }
  let raw_nodes = array_property(object, "nodes", "$")
  let raw_edges = array_property(object, "edges", "$")
  let packages : Array[String] = []
  for index in 0..<raw_nodes.length() {
    let path = index_path("$.nodes", index)
    let node = as_object(raw_nodes[index], path)
    let module_name = string_property(node, "module", path)
    let relative = string_property(node, "rel", path)
    if module_name.is_empty() {
      raise MoonTreeError::InvalidShape(path + ".module")
    }
    packages.push(
      if relative.is_empty() {
        module_name
      } else {
        module_name + "/" + relative
      },
    )
  }
  let edges : Array[@graph.Edge] = []
  for edge_index in 0..<raw_edges.length() {
    let path = index_path("$.edges", edge_index)
    let edge = as_object(raw_edges[edge_index], path)
    let source_index = int_property(edge, "from", path)
    let target_index = int_property(edge, "to", path)
    if source_index < 0 ||
      source_index >= packages.length() ||
      target_index < 0 ||
      target_index >= packages.length() {
      raise MoonTreeError::InvalidShape(path)
    }
    let kinds = array_property(edge, "kinds", path)
    for kind_index in 0..<kinds.length() {
      let kind_name = string_value(
        kinds[kind_index],
        index_path(path + ".kinds", kind_index),
      )
      let kind = match kind_name {
        "source" => @graph.Normal
        "blackbox-test" => @graph.Test
        "whitebox-test" => @graph.Wbtest
        _ => raise MoonTreeError::InvalidEdgeKind(kind_name)
      }
      edges.push(
        @graph.Edge::new(
          source=packages[source_index],
          target=packages[target_index],
          kind~,
        ),
      )
    }
  }
  @graph.normalize(packages, edges) catch {
    _ => raise MoonTreeError::InvalidGraph
  }
}

///|
fn as_object(
  value : Json,
  path : String,
) -> Map[String, Json] raise MoonTreeError {
  match value {
    Object(fields) => fields
    _ => raise MoonTreeError::InvalidShape(path)
  }
}

///|
fn array_property(
  object : Map[String, Json],
  key : String,
  path : String,
) -> Array[Json] raise MoonTreeError {
  match object.get(key) {
    Some(Array(values)) => values
    _ => raise MoonTreeError::InvalidShape(path + "." + key)
  }
}

///|
fn string_property(
  object : Map[String, Json],
  key : String,
  path : String,
) -> String raise MoonTreeError {
  match object.get(key) {
    Some(String(value)) => value
    _ => raise MoonTreeError::InvalidShape(path + "." + key)
  }
}

///|
fn int_property(
  object : Map[String, Json],
  key : String,
  path : String,
) -> Int32 raise MoonTreeError {
  match object.get(key) {
    Some(Number(_, ..) as value) =>
      @json.from_json(value) catch {
        _ => raise MoonTreeError::InvalidShape(path + "." + key)
      }
    _ => raise MoonTreeError::InvalidShape(path + "." + key)
  }
}

///|
fn string_value(value : Json, path : String) -> String raise MoonTreeError {
  match value {
    String(text) => text
    _ => raise MoonTreeError::InvalidShape(path)
  }
}

///|
fn index_path(path : String, index : Int32) -> String {
  path + "[" + index.to_string() + "]"
}
