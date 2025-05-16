// std imports
import gleam/io
import gleam/result

// internal imports 
import hebi/registry.{fetch_package_meta, new_parser, parse_chars}

pub fn main() {
  let resp =
    fetch_package_meta("typescript")
    |> result.unwrap("failed to fetch ts package meta json from npm registry")
  // io.debug(resp)

  let parser = new_parser(resp)
  // io.debug(parser)

  parse_chars(parser) |> io.debug()
}
