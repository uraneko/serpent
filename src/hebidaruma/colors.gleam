const color_picker = "\u{1b}[1;38;2;"

const color_clear = "\u{1b}[0m"

pub const red = "231;43;23m"

pub const green = "159;221;168m"

pub const blue = "159;151;248m"

pub const rose = "255;120;192m"

pub const yellow = "245;214;173m"

/// styles the passed text value with the passed color
/// NOTE: all color consts have bold turned on 
pub fn colorize(text: String, color: String) -> String {
  color_picker <> color <> text <> color_clear
}
