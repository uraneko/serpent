// std imports
import gleam/io
import gleam/result

// internal imports 
import hebidaruma/registry.{fetch_package_meta, new_parser, parse_chars}

pub fn main() {
  let resp =
    fetch_package_meta("typescript")
    |> result.unwrap("bad desu yo")
  io.debug(resp)

  let parser = new_parser(resp)
  io.debug(parser)

  let json = parse_chars(parser)
  json |> io.debug()
}
