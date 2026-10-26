///|
pub async fn run_args(args : Array[String]) -> Int32 {
  let command = parse_args(args) catch {
    error => {
      write_stderr(
        "moonarch: " + error_message(error) + "\n\n" + help_text() + "\n",
      )
      return 2
    }
  }
  run_command(command)
}

///|
async fn run_command(command : @application.CliCommand) -> Int32 {
  try {
    match command {
      @application.Help => {
        write_stdout(help_text() + "\n")
        0
      }
      @application.Version => {
        write_stdout(version() + "\n")
        0
      }
      @application.ValidateConfig(path) => {
        @application.validate_config_file(path)
        write_stdout("configuration valid: " + path + "\n")
        0
      }
      @application.Check(options) => {
        let execution = @application.run_check(options)
        let text = @application.render_report(
          execution.report,
          options.format,
          options.color,
        )
        @application.write_result(options.output_path, text)
        execution.exit_code
      }
      @application.CreateBaseline(options, path) => {
        @application.create_baseline(options, path)
        write_stdout("baseline written: " + path + "\n")
        0
      }
    }
  } catch {
    @application.Configuration(message) => {
      write_stderr("moonarch: configuration error: " + message + "\n")
      2
    }
    @application.GraphInput(message) => {
      write_stderr("moonarch: graph input error: " + message + "\n")
      3
    }
    @application.ProcessFailure(message) => {
      write_stderr("moonarch: process error: " + message + "\n")
      3
    }
    @application.PolicyConfiguration(message) => {
      write_stderr("moonarch: policy error: " + message + "\n")
      2
    }
    @application.BaselineInput(message) => {
      write_stderr("moonarch: baseline error: " + message + "\n")
      3
    }
    @application.OutputFailure(message) => {
      write_stderr("moonarch: output error: " + message + "\n")
      3
    }
    _ => {
      write_stderr("moonarch: unexpected error\n")
      4
    }
  }
}

///|
async fn write_stdout(text : String) -> Unit {
  @stdio.stdout.write(text) catch {
    _ => ()
  }
}

///|
async fn write_stderr(text : String) -> Unit {
  @stdio.stderr.write(text) catch {
    _ => ()
  }
}
