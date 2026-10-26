///|
test "single star matches a package segment and double star spans segments" {
  assert_true(@selector.matches("acme/*", "acme/app"))
  assert_false(@selector.matches("acme/*", "acme/app/internal"))
  assert_true(@selector.matches("acme/**", "acme/app/internal"))
  assert_true(@selector.matches("acme/**", "acme"))
  assert_true(@selector.matches("acme/*/core-*", "acme/app/core-domain"))
}

///|
test "expand returns sorted unique package names" {
  assert_eq(
    @selector.expand(["acme/**", "acme/app"], ["z/pkg", "acme/app", "acme/lib"]),
    ["acme/app", "acme/lib"],
  )
  assert_eq(@selector.expand(["**"], ["zz", "a", "bb"]), ["a", "bb", "zz"])
}

///|
test "empty pattern and malformed separators are errors" {
  try {
    @selector.expand([""], ["acme/app"]) |> ignore
    fail("empty pattern must be rejected")
  } catch {
    @selector.SelectorError::EmptyPattern => ()
    _ => fail("unexpected selector error")
  }
  try {
    @selector.expand(["acme//app"], ["acme/app"]) |> ignore
    fail("repeated separator must be rejected")
  } catch {
    @selector.SelectorError::MalformedPattern(_) => ()
    _ => fail("unexpected selector error")
  }
}

///|
test "package selectors reject dot path segments" {
  assert_false(@selector.matches("**", "acme/./app"))
  assert_false(@selector.matches("**", "acme/../app"))
  assert_false(@selector.matches("**", "../app"))
  assert_false(@selector.validate_pattern("acme/./app"))
  assert_false(@selector.validate_pattern("acme/../app"))
}
