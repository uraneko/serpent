// std imports 
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string

// internal imports
// import hebi/run

// external imports
import argv

const bor = int.bitwise_or

type Option(a) =
  option.Option(a)

type Dict(a, b) =
  dict.Dict(a, b)

pub type CLIResult {
  CLIOk(CLIOk)
  CLIErr(CLIErr)
}

type ParseState {
  Ongoing(Int)
  Done(Int)
  Aborted(CLIErr)
}

pub type CLIErr {
  UnrecognizedOption(String)
  UnsupportedCommand(String)
  MissingOptionArgument(String)
  BadArgumentValue(String)
}

pub type CLIOk {
  RecursionDone(Int)
  RecursionDonePlusOpts(#(Int, Dict(String, String)))
}

pub type CLICommand {
  Help
  Version
  Init(Option(InitData))
  Log
}

pub type InitData {
  Opts(Int)
  OptsWithArgs(opts: Int, args: Dict(String, String))
  InitErr(CLIErr)
}

/// parses the command action given by the user
fn parse_cmd(action: String) -> Result(CLICommand, CLIErr) {
  case action {
    "help" | "h" -> Ok(Help)
    "version" | "v" -> Ok(Version)
    "init" | "i" -> Ok(Init(option.None))
    "log" | "l" -> Ok(Log)
    cmd -> Error(UnsupportedCommand(cmd))
  }
}

/// parses the command action arguments given by the user if any 
/// returns an octet with the relevant bits switched on 
fn parse_opts(vals: List(String), mask: Int) -> Result(Int, CLIErr) {
  let mask = case vals |> list.first() |> result.unwrap("done") {
    "--lib" | "-L" -> Ongoing(mask |> bor(1))
    "--no-tests" | "-nT" -> Ongoing(mask |> bor(2))
    "--no-docs" | "-nD" -> Ongoing(mask |> bor(4))
    "--no-git" | "-nG" -> Ongoing(mask |> bor(8))
    // unreachable, logic wise
    "--log-level" | "-lL" -> Ongoing(mask |> bor(16))
    "--keep-logs" | "-kL" -> Ongoing(mask |> bor(32))
    // unreachable, logic wise
    "--install-server" | "-S" -> Ongoing(mask |> bor(64))
    "--install-deps" | "-iD" -> Ongoing(mask |> bor(128))
    // done
    "done" -> Done(mask)
    opt -> Aborted(UnrecognizedOption(opt))
  }

  case mask {
    Ongoing(mask) -> parse_opts(list.rest(vals) |> result.unwrap([]), mask)
    Done(mask) -> Ok(mask)
    Aborted(e) -> Error(e)
  }
}

/// parses the command action arguments given by the user if any 
/// returns an octet with the relevant bits switched on 
/// and an args dictionary with the values of arguments that take a value 
fn parse_opts_with_args(
  vals: List(String),
  args: Dict(String, String),
  mask: Int,
) -> Result(#(Int, Dict(String, String)), CLIErr) {
  let args_size = dict.size(args)
  let bad_args_size =
    args
    |> dict.values()
    |> list.count(fn(s: String) { s |> string.is_empty() })

  let mask = case vals |> list.first() |> result.unwrap("done") {
    "--lib" | "-L" -> Ongoing(mask |> bor(1))
    "--no-tests" | "-nT" -> Ongoing(mask |> bor(2))
    "--no-docs" | "-nD" -> Ongoing(mask |> bor(4))
    "--no-git" | "-nG" -> Ongoing(mask |> bor(8))
    "--log-level" | "-lL" -> {
      args
      |> dict.insert("log-level", resolve_loglv(vals))

      Ongoing(mask |> bor(16))
    }
    "--keep-logs" | "-kL" -> Ongoing(mask |> bor(32))
    "--install-server" | "-S" -> {
      args |> dict.insert("server-port", resolve_server_port(vals))
      Ongoing(mask |> bor(64))
    }
    "--install-deps" | "-iD" -> Ongoing(mask |> bor(128))
    // done
    "done" -> Done(mask)
    // opt -> panic as { "bad option given" <> opt }
    opt -> Aborted(UnrecognizedOption(opt))
  }

  case mask {
    Aborted(e) -> Error(e)
    Ongoing(mask) -> {
      let size_diff = { args |> dict.size() } - args_size
      let bad_size_diff =
        {
          args
          |> dict.values()
          |> list.count(fn(s: String) { s |> string.is_empty() })
        }
        - bad_args_size

      let vals = case size_diff, bad_size_diff {
        0, 0 | 1, 0 -> list.rest(vals) |> result.unwrap([])
        1, 1 ->
          vals
          |> list.rest()
          |> result.unwrap([])
          |> list.rest()
          |> result.unwrap([])
        _, _ -> panic as "unreachable"
      }

      parse_opts_with_args(vals, args, mask)
    }
    Done(mask) -> {
      Ok(#(mask, args))
    }
  }
}

// default port number for the server 
const default_port = "7365"

// default log level 
const default_loglv = "TRACE"

/// iterates through the arguments dictionary and 
/// sets the default values for arguments that are empty (were bad or missing)
fn resolve_args(args: Dict(String, String)) -> Dict(String, String) {
  args
  |> dict.map_values(fn(k, v) {
    case v |> string.is_empty() {
      True ->
        case k {
          "server-port" -> default_port
          "log-level" -> default_loglv
          _ -> panic as "unreachable"
        }
      False -> v
    }
  })
}

// returns the server port number argument from the values list 
// or an empty string if the value is bad or missing 
fn resolve_server_port(vals: List(String)) -> String {
  case vals |> list.drop({ vals |> list.length() } - 2) |> list.last() {
    Ok(arg) ->
      case
        arg |> string.length() == 4
        && arg
        |> string.to_utf_codepoints
        |> list.all(fn(ucp: UtfCodepoint) {
          let ucp = ucp |> string.utf_codepoint_to_int()
          ucp >= 48 && ucp <= 57
        })
      {
        True -> arg
        // BadArgumentValue
        False -> ""
      }
    // MissingArgument
    Error(_) -> ""
    // Error(_) -> { io.println("") Err(CLIErr(MissingArgument)) }
  }
}

// returns the log level argument from the values list 
// or an empty string if the value is bad or missing 
fn resolve_loglv(vals: List(String)) -> String {
  case vals |> list.drop({ vals |> list.length() } - 2) |> list.last() {
    Ok(arg) ->
      case arg {
        "FATAL" | "DEBUG" | "ERROR" | "INFO" | "WARN" | "TRACE" -> arg
        // BadArgumentValue
        _ -> ""
      }
    // MissingArgument
    Error(_) -> ""
    // Error(_) -> { io.println("") Err(CLIErr(MissingArgument)) }
  }
}

/// parses the given cli command args and returns a CliCommand 
/// specifying which callbacks should be invoked afterwards
pub fn parse() -> CLICommand {
  let args = argv.load().arguments

  // TODO proper error handling 
  let cmd =
    args
    |> list.first()
    |> result.unwrap("")
    |> parse_cmd()
    |> result.unwrap(Help)

  case cmd {
    Help -> Help
    Version -> Version
    Log -> Log
    Init(_) -> {
      let opts = case
        args |> list.contains("--install-server")
        || args |> list.contains("--log-level")
      {
        True -> {
          case
            parse_opts_with_args(
              args |> list.rest() |> result.unwrap([]),
              dict.new(),
              0x0,
            )
          {
            Ok(res) -> Init(option.Some(OptsWithArgs(opts: res.0, args: res.1)))
            Error(e) -> Init(option.Some(InitErr(e)))
          }
        }
        False ->
          case parse_opts(args |> list.rest() |> result.unwrap([]), 0x0) {
            Ok(int) -> Init(option.Some(Opts(int)))
            Error(e) -> Init(option.Some(InitErr(e)))
          }
      }
    }
  }
}
