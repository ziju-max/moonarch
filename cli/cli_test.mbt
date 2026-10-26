///|
test "version is stable" {
  assert_eq(@cli.version(), "moonarch 0.1.0")
}

///|
test "check parses offline mode and deterministic report flags" {
  match
    @cli.parse_args([
      "check", "--config", "rules.json", "--graph", "tree.json", "--format", "json",
      "--color", "never",
    ]) {
    @application.Check(options) => {
      assert_eq(options.config_path, "rules.json")
      assert_true(
        options.graph_source is @application.OfflineGraph("tree.json"),
      )
      assert_true(options.format is @application.JsonOutput)
    }
    _ => fail("expected check command")
  }
}

///|
test "check rejects conflicting graph inputs and unknown formats" {
  try {
    @cli.parse_args(["check", "--graph", "tree.json", "--workspace", "."])
    |> ignore
    fail("conflicting input modes must fail")
  } catch {
    @application.ConflictingInputs => ()
    _ => fail("expected conflicting input error")
  }
  try {
    @cli.parse_args(["check", "--graph", "tree.json", "--format", "xml"])
    |> ignore
    fail("unknown report format must fail")
  } catch {
    @application.InvalidValue(option="--format", value="xml") => ()
    _ => fail("expected invalid-format error")
  }
}

///|
test "commands reject missing sources, values, and baseline output" {
  try {
    @cli.parse_args(["check"]) |> ignore
    fail("check must require an input source")
  } catch {
    @application.MissingGraphSource => ()
    _ => fail("expected missing graph source")
  }
  try {
    @cli.parse_args(["check", "--graph"]) |> ignore
    fail("graph option must require a value")
  } catch {
    @application.MissingValue("--graph") => ()
    _ => fail("expected missing option value")
  }
  try {
    @cli.parse_args(["baseline", "create", "--graph", "tree.json"]) |> ignore
    fail("baseline creation must require an output")
  } catch {
    @application.MissingOutput => ()
    _ => fail("expected missing baseline output")
  }
}

///|
test "help is available after a subcommand and unknown options are rejected" {
  assert_true(@cli.parse_args(["check", "--help"]) is @application.Help)
  try {
    @cli.parse_args(["check", "--graph", "tree.json", "--mystery"]) |> ignore
    fail("unknown option must fail")
  } catch {
    @application.UnknownOption("--mystery") => ()
    _ => fail("expected unknown option")
  }
}

///|
test "short aliases and explicit report paths are preserved" {
  assert_true(@cli.parse_args(["-h"]) is @application.Help)
  assert_true(@cli.parse_args(["-V"]) is @application.Version)
  match
    @cli.parse_args([
      "check", "--graph", "tree.json", "--output", "report.md", "--format", "markdown",
    ]) {
    @application.Check(options) => {
      assert_true(options.output_path is Some("report.md"))
      assert_true(options.format is @application.MarkdownOutput)
    }
    _ => fail("expected check command")
  }
}
