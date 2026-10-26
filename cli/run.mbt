///|
pub async fn run_args(args : Array[String]) -> Int32 {
  let command = parse_args(args) catch {
    error => {
      write_stderr(
        "moonarch: " +
        @report.sanitize_terminal_text(error_message(error)) +
        "\n\n" +
        help_text() +
        "\n",
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
      @application.Help => write_success_message(help_text() + "\n")
      @application.Version => write_success_message(version() + "\n")
      @application.ValidateConfig(path) => {
        @application.validate_config_file(path)
        write_success_message("configuration valid: " + path + "\n")
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
        write_success_message("baseline written: " + path + "\n")
      }
    }
  } catch {
    @application.Configuration(message) => {
      write_stderr_error("moonarch: configuration error: ", message)
      2
    }
    @application.GraphInput(message) => {
      write_stderr_error("moonarch: graph input error: ", message)
      3
    }
    @application.ProcessFailure(message) => {
      write_stderr_error("moonarch: process error: ", message)
      3
    }
    @application.PolicyConfiguration(message) => {
      write_stderr_error("moonarch: policy error: ", message)
      2
    }
    @application.BaselineInput(message) => {
      write_stderr_error("moonarch: baseline error: ", message)
      3
    }
    @application.OutputFailure(message) => {
      write_stderr_error("moonarch: output error: ", message)
      3
    }
    _ => {
      write_stderr("moonarch: unexpected error\n")
      4
    }
  }
}

///|
async fn write_success_message(text : String) -> Int32 {
  if write_stdout(text) {
    0
  } else {
    write_stderr("moonarch: output error: could not write to stdout\n")
    3
  }
}

///|
async fn write_stdout(text : String) -> Bool {
  @stdio.stdout.write(text) catch {
    _ => return false
  }
  true
}

///|
async fn write_stderr(text : String) -> Unit {
  @stdio.stderr.write(text) catch {
    _ => ()
  }
}

///|
async fn write_stderr_error(prefix : String, message : String) -> Unit {
  write_stderr(prefix + @report.sanitize_terminal_text(message) + "\n")
}
