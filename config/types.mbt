///|
pub(all) struct Scope {
  includes : Array[String]
  exclude : Array[String]
}

///|
pub(all) struct Group {
  id : String
  packages : Array[String]
}

///|
pub(all) struct Layer {
  id : String
  packages : Array[String]
  level : Int32
}

///|
pub(all) struct DenyRule {
  id : String
  from : Array[String]
  to : Array[String]
  transitive : Bool
  contexts : Array[@graph.Context]
}

///|
pub(all) struct AllowOnlyRule {
  id : String
  from : Array[String]
  allow : Array[String]
  contexts : Array[@graph.Context]
}

///|
pub(all) struct LayerDirectionRule {
  id : String
  contexts : Array[@graph.Context]
}

///|
pub(all) struct MaxLayerJumpRule {
  id : String
  max : Int32
  contexts : Array[@graph.Context]
}

///|
pub(all) enum Rule {
  Deny(DenyRule)
  AllowOnly(AllowOnlyRule)
  LayerDirection(LayerDirectionRule)
  MaxLayerJump(MaxLayerJumpRule)
}

///|
pub(all) struct Exception {
  rule_id : String
  source : String
  target : String
  context : @graph.Context
  reason : String
  owner : String
  expires : String
}

///|
pub(all) struct Config {
  schema_version : Int32
  scope : Scope
  groups : Array[Group]
  layers : Array[Layer]
  rules : Array[Rule]
  exceptions : Array[Exception]
  baseline : String?
}

///|
pub(all) suberror ConfigError {
  InvalidJson(String)
  ExpectedObject(String)
  ExpectedArray(String)
  MissingField(String)
  TypeMismatch(String)
  UnknownField(path~ : String)
  InvalidValue(path~ : String, detail~ : String)
  DuplicateId(id~ : String)
  UnknownGroup(path~ : String, id~ : String)
  DuplicateContext(path~ : String, context~ : String)
  InvalidDate(path~ : String, value~ : String)
}

///|
pub fn Rule::id(self : Rule) -> String {
  match self {
    Deny(rule) => rule.id
    AllowOnly(rule) => rule.id
    LayerDirection(rule) => rule.id
    MaxLayerJump(rule) => rule.id
  }
}
