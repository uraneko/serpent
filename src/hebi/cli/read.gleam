// std imports 
import gleam/int
import gleam/io
import gleam/list
import gleam/result

// external imports 
import envoy
import simplifile

const band = int.bitwise_and

const default_files = ["index.html", "package-bin.json", "rollup.config.js"]

pub fn get_defaults_path() -> String {
  envoy.get("JS_DEFAULTS")
  |> result.unwrap("you need to set the JS_DEFAULTS env var")
}

/// scans the js defaults dir and returns all the file names found there 
pub fn scan_defaults_dir(at dir: String) -> List(String) {
  case simplifile.read_directory(at: dir) {
    Error(e) -> {
      io.debug(e)
      io.println("couldnt find js default config files, exiting hebi")
      panic as "bad desu yo"
    }
    Ok(files) -> files
  }
}

/// reads the data of the files needed for the init command to run 
pub fn read_defaults(defs: List(String)) -> List(String) {
  list.map(defs, fn(def: String) -> String {
    simplifile.read(def) |> result.unwrap("failed to read file data")
  })
}

/// takes all the files in js defaults dir 
/// and keeps only the files relevant to 
/// the command and arguments given by the user 
pub fn filter_defaults(
  defs: List(String),
  all_defs: List(String),
) -> List(String) {
  list.filter(defs, fn(def) { all_defs |> list.contains(def) })
}

pub fn resolve_files(files: List(String), opts: Int, mask) -> List(String) {
  case opts == 0 {
    True -> files
    False ->
      case opts |> band(mask) {
        0 -> files
        bit ->
          case bit {
            // --lib
            1 ->
              files
              |> list.filter(fn(f) {
                !{ ["rollup.config.js", "index.html"] |> list.contains(f) }
              })
              |> list.map(fn(f) {
                case f {
                  "package-bin.json" -> "package-lib.json"
                  file -> file
                }
              })
            2 -> {
              todo
            }
            bit -> panic
          }
      }
  }
}
