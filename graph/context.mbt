///|
pub fn Context::allows(self : Context, kind : ImportKind) -> Bool {
  match self {
    NormalContext => kind == Normal
    TestContext => kind == Normal || kind == Test
    WbtestContext => kind == Normal || kind == Wbtest
  }
}

///|
pub fn Context::required_kind(self : Context) -> ImportKind? {
  match self {
    NormalContext => None
    TestContext => Some(Test)
    WbtestContext => Some(Wbtest)
  }
}

///|
pub fn Context::as_string(self : Context) -> String {
  match self {
    NormalContext => "normal"
    TestContext => "test"
    WbtestContext => "wbtest"
  }
}

///|
pub fn ImportKind::as_string(self : ImportKind) -> String {
  match self {
    Normal => "normal"
    Test => "test"
    Wbtest => "wbtest"
  }
}
