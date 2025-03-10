// std imports
import gleam/io
import gleam/result

// internal imports 
import hebidaruma/registry.{fetch_package_meta}

pub fn main() {
  fetch_package_meta("typescript")
  |> result.unwrap("bad desu yo")
  |> io.println()
}
