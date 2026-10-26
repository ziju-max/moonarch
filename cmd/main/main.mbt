///|
async fn main {
  let raw_args = @env.args()
  let args : Array[String] = []
  for index in 1..<raw_args.length() {
    args.push(raw_args[index])
  }
  let exit_code = @cli.run_args(args)
  @sys.exit(exit_code)
}
