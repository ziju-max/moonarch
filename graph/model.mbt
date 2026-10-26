///|
pub(all) enum ImportKind {
  Normal
  Test
  Wbtest
} derive(Eq)

///|
pub(all) enum Context {
  NormalContext
  TestContext
  WbtestContext
} derive(Eq)

///|
pub(all) struct Edge {
  source : String
  target : String
  kind : ImportKind
} derive(Eq)

///|
pub fn Edge::new(
  source~ : String,
  target~ : String,
  kind~ : ImportKind,
) -> Edge {
  { source, target, kind, }
}

///|
pub fn Edge::source(self : Edge) -> String {
  self.source
}

///|
pub fn Edge::target(self : Edge) -> String {
  self.target
}

///|
pub fn Edge::kind(self : Edge) -> ImportKind {
  self.kind
}

///|
pub(all) suberror GraphError {
  EmptyPackageName
  InvalidPackageName(String)
  DanglingEdge(String, String)
}
