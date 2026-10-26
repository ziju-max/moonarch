///|
pub(all) struct Violation {
  rule_id : String
  source : String
  target : String
  context : @graph.Context
  path : Array[@graph.Edge]
}

///|
pub(all) struct PolicyWarning {
  code : String
  group_id : String
  message : String
}

///|
pub(all) struct PolicyEvaluation {
  violations : Array[Violation]
  warnings : Array[PolicyWarning]
}

///|
pub(all) suberror PolicyError {
  MissingLayer(String)
  OverlappingLayers(String)
}
