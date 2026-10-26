///|
pub(all) enum GraphSource {
  OfflineGraph(String)
  Workspace(String)
}

///|
pub(all) enum OutputFormat {
  TerminalOutput
  JsonOutput
  MarkdownOutput
}

///|
pub(all) enum ColorMode {
  AutoColor
  AlwaysColor
  NeverColor
}

///|
pub(all) struct CheckOptions {
  config_path : String
  graph_source : GraphSource
  moon_executable : String
  format : OutputFormat
  color : ColorMode
  output_path : String?
}

///|
pub(all) suberror CliError {
  UnknownOption(String)
  MissingValue(String)
  InvalidValue(option~ : String, value~ : String)
  ConflictingInputs
  MissingGraphSource
  MissingOutput
  UnexpectedArgument(String)
}

///|
pub(all) enum CliCommand {
  Help
  Version
  ValidateConfig(String)
  Check(CheckOptions)
  CreateBaseline(CheckOptions, String)
}

///|
pub(all) suberror ApplicationError {
  Configuration(String)
  GraphInput(String)
  ProcessFailure(String)
  PolicyConfiguration(String)
  BaselineInput(String)
  OutputFailure(String)
}

///|
pub(all) struct CheckExecution {
  report : @report.Report
  exit_code : Int32
}
