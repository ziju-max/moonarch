///|
fn flatten_report_controls(value : String) -> String {
  let pieces = value
    .to_array()
    .map(character => {
      if is_report_control(character.to_int()) {
        " "
      } else {
        character.to_string()
      }
    })
  pieces.join("")
}

///|
fn is_report_control(code : Int32) -> Bool {
  code <= 0x1F ||
  (code >= 0x7F && code <= 0x9F) ||
  code == 0x2028 ||
  code == 0x2029
}
