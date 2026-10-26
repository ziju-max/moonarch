///|
priv struct SearchState {
  package_name : String
  has_required_kind : Bool
  path : Array[@graph.Edge]
}

///|
pub fn find_path(
  graph : @graph.Graph,
  source : String,
  target : String,
  context : @graph.Context,
) -> Array[@graph.Edge]? {
  if !graph.has_package(source) || !graph.has_package(target) {
    return None
  }
  let queue : Array[SearchState] = [
    {
      package_name: source,
      has_required_kind: context.required_kind() is None,
      path: [],
    },
  ]
  let visited : Array[(String, Bool)] = [
    (source, context.required_kind() is None),
  ]
  let mut head = 0
  while head < queue.length() {
    let state = queue[head]
    head = head + 1
    if state.package_name == target && state.has_required_kind {
      return Some(state.path)
    }
    for edge in graph.outgoing(state.package_name, context) {
      let has_required_kind = state.has_required_kind ||
        context.required_kind() == Some(edge.kind())
      let visit_key = (edge.target(), has_required_kind)
      if !visited.contains(visit_key) {
        visited.push(visit_key)
        let next_path = state.path.copy()
        next_path.push(edge)
        queue.push({
          package_name: edge.target(),
          has_required_kind,
          path: next_path,
        })
      }
    }
  }
  None
}

///|
pub fn path_contains_required_kind(
  path : Array[@graph.Edge],
  context : @graph.Context,
) -> Bool {
  match context.required_kind() {
    None => true
    Some(required_kind) => {
      for edge in path {
        if edge.kind() == required_kind {
          return true
        }
      }
      false
    }
  }
}
