///|
pub(all) struct Violation {
  rule_id : String
  source : String
  target : String
  context : @graph.Context
  path : Array[@graph.Edge]
}

///|
pub(all) suberror PolicyError {
  MissingLayer(String)
  OverlappingLayers(String)
}
