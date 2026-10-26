///|
pub struct Graph {
  packages : Array[String]
  edges : Array[Edge]
}

///|
pub fn normalize(
  packages : Array[String],
  edges : Array[Edge],
) -> Graph raise GraphError {
  let sorted_packages = packages.copy()
  sorted_packages.sort_by(text_order)
  let unique_packages : Array[String] = []
  for package_name in sorted_packages {
    if package_name.trim().is_empty() {
      raise GraphError::EmptyPackageName
    }
    if !@selector.is_valid_package_name(package_name) {
      raise GraphError::InvalidPackageName(package_name)
    }
    if unique_packages.is_empty() ||
      unique_packages[unique_packages.length() - 1] != package_name {
      unique_packages.push(package_name)
    }
  }
  let sorted_edges = edges.copy()
  sorted_edges.sort_by(edge_order)
  let unique_edges : Array[Edge] = []
  for edge in sorted_edges {
    if !unique_packages.contains(edge.source) {
      raise GraphError::DanglingEdge(edge.source, edge.target)
    }
    if !unique_packages.contains(edge.target) {
      raise GraphError::DanglingEdge(edge.source, edge.target)
    }
    if unique_edges.is_empty() ||
      !same_edge(unique_edges[unique_edges.length() - 1], edge) {
      unique_edges.push(edge)
    }
  }
  { packages: unique_packages, edges: unique_edges, }
}

///|
fn edge_order(left : Edge, right : Edge) -> Int32 {
  let source_order = text_order(left.source, right.source)
  if source_order != 0 {
    return source_order
  }
  let target_order = text_order(left.target, right.target)
  if target_order != 0 {
    return target_order
  }
  text_order(left.kind.as_string(), right.kind.as_string())
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
fn same_edge(left : Edge, right : Edge) -> Bool {
  left.source == right.source &&
  left.target == right.target &&
  left.kind == right.kind
}

///|
pub fn Graph::packages(self : Graph) -> Array[String] {
  self.packages.copy()
}

///|
pub fn Graph::edges(self : Graph) -> Array[Edge] {
  self.edges.copy()
}

///|
pub fn Graph::has_package(self : Graph, name : String) -> Bool {
  self.packages.contains(name)
}

///|
pub fn Graph::has_edge(
  self : Graph,
  source : String,
  target : String,
  kind : ImportKind,
) -> Bool {
  for edge in self.edges {
    if edge.source == source && edge.target == target && edge.kind == kind {
      return true
    }
  }
  false
}

///|
pub fn Graph::outgoing(
  self : Graph,
  source : String,
  context : Context,
) -> Array[Edge] {
  let found : Array[Edge] = []
  for edge in self.edges {
    if edge.source == source && context.allows(edge.kind) {
      found.push(edge)
    }
  }
  found
}
