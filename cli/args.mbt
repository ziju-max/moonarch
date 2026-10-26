///|
pub fn parse_args(
  args : Array[String],
) -> @application.CliCommand raise @application.CliError {
  if args.is_empty() {
    return @application.Help
  }
  if args.iter().any(value => value == "--help" || value == "-h") {
    return @application.Help
  }
  match args[0] {
    "--help" | "-h" | "help" => @application.Help
    "--version" | "-V" => @application.Version
    "check" => @application.Check(parse_check_options(args, 1, false))
    "config" => parse_config_command(args)
    "baseline" => parse_baseline_command(args)
    command => raise @application.CliError::UnexpectedArgument(command)
  }
}

///|
fn parse_config_command(
  args : Array[String],
) -> @application.CliCommand raise @application.CliError {
  if args.length() < 2 || args[1] != "validate" {
    raise @application.CliError::UnexpectedArgument(
      "expected `config validate`",
    )
  }
  let mut config_path = "moonarch.json"
  let mut index = 2
  while index < args.length() {
    let option = args[index]
    index = index + 1
    match option {
      "--config" => {
        config_path = take_value(args, index, option).0
        index = index + 1
      }
      "--help" | "-h" => return @application.Help
      _ => raise @application.CliError::UnknownOption(option)
    }
  }
  @application.ValidateConfig(config_path)
}

///|
fn parse_baseline_command(
  args : Array[String],
) -> @application.CliCommand raise @application.CliError {
  if args.length() < 2 || args[1] != "create" {
    raise @application.CliError::UnexpectedArgument(
      "expected `baseline create`",
    )
  }
  let options = parse_check_options(args, 2, true)
  let output_path = match options.output_path {
    Some(path) => path
    None => raise @application.CliError::MissingOutput
  }
  @application.CreateBaseline(options, output_path)
}

///|
fn parse_check_options(
  args : Array[String],
  start : Int32,
  output_required : Bool,
) -> @application.CheckOptions raise @application.CliError {
  let mut config_path = "moonarch.json"
  let mut graph_file : String? = None
  let mut workspace : String? = None
  let mut moon_executable = "moon"
  let mut format = @application.TerminalOutput
  let mut color = @application.AutoColor
  let mut output_path : String? = None
  let mut index = start
  while index < args.length() {
    let option = args[index]
    index = index + 1
    match option {
      "--config" => {
        config_path = take_value(args, index, option).0
        index = index + 1
      }
      "--graph" => {
        if workspace is Some(_) {
          raise @application.CliError::ConflictingInputs
        }
        graph_file = Some(take_value(args, index, option).0)
        index = index + 1
      }
      "--workspace" => {
        if graph_file is Some(_) {
          raise @application.CliError::ConflictingInputs
        }
        workspace = Some(take_value(args, index, option).0)
        index = index + 1
      }
      "--moon" => {
        moon_executable = take_value(args, index, option).0
        index = index + 1
      }
      "--format" => {
        let value = take_value(args, index, option).0
        index = index + 1
        format = match value {
          "terminal" => @application.TerminalOutput
          "json" => @application.JsonOutput
          "markdown" => @application.MarkdownOutput
          _ => raise @application.CliError::InvalidValue(option~, value~)
        }
      }
      "--color" => {
        let value = take_value(args, index, option).0
        index = index + 1
        color = match value {
          "auto" => @application.AutoColor
          "always" => @application.AlwaysColor
          "never" => @application.NeverColor
          _ => raise @application.CliError::InvalidValue(option~, value~)
        }
      }
      "--output" => {
        output_path = Some(take_value(args, index, option).0)
        index = index + 1
      }
      "--help" | "-h" =>
        raise @application.CliError::UnexpectedArgument("help requested")
      value if value.has_prefix("-") =>
        raise @application.CliError::UnknownOption(value)
      value => raise @application.CliError::UnexpectedArgument(value)
    }
  }
  let graph_source = match (graph_file, workspace) {
    (Some(path), None) => @application.OfflineGraph(path)
    (None, Some(path)) => @application.Workspace(path)
    (None, None) => raise @application.CliError::MissingGraphSource
    (Some(_), Some(_)) => raise @application.CliError::ConflictingInputs
  }
  if output_required && output_path is None {
    raise @application.CliError::MissingOutput
  }
  { config_path, graph_source, moon_executable, format, color, output_path, }
}

///|
fn take_value(
  args : Array[String],
  index : Int32,
  option : String,
) -> (String, Unit) raise @application.CliError {
  if index >= args.length() {
    raise @application.CliError::MissingValue(option)
  }
  let value = args[index]
  if value.is_empty() || value.has_prefix("--") {
    raise @application.CliError::MissingValue(option)
  }
  (value, ())
}

///|
pub fn error_message(error : @application.CliError) -> String {
  match error {
    @application.UnknownOption(option) => "unknown option: " + option
    @application.MissingValue(option) => "missing value for " + option
    @application.InvalidValue(option~, value~) =>
      "invalid value for " + option + ": " + value
    @application.ConflictingInputs =>
      "--graph and --workspace cannot be used together"
    @application.MissingGraphSource =>
      "provide exactly one of --graph or --workspace"
    @application.MissingOutput => "--output is required for baseline create"
    @application.UnexpectedArgument(value) => "unexpected argument: " + value
  }
}

///|
pub fn help_text() -> String {
  (
    #|MoonArch 0.1.0 - deterministic MoonBit package architecture checks
    #|
    #|Usage:
    #|  moonarch check --config moonarch.json (--graph graph.json | --workspace DIR) [--moon EXE] [--format terminal|json|markdown] [--color auto|always|never] [--output FILE]
    #|  moonarch config validate [--config FILE]
    #|  moonarch baseline create --output FILE --config FILE (--graph graph.json | --workspace DIR) [--moon EXE]
    #|  moonarch --help
    #|  moonarch --version
  )
}
