// std imports 
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string

type Dict(a, b) =
  dict.Dict(a, b)

// internal imports
import hebi/colors.{blue, colorize, green, red, rose, yellow}
import hebi/parse.{
  type CLICommand, type InitData, Help, Init, InitErr, Log, Opts, OptsWithArgs,
  Version,
}

// external imports 
// import envoy
import simplifile

type HelpOpt {
  HelpOpt(name: String, desc: String, arg: option.Option(String))
}

type HelpCmd {
  HelpCmd(name: String, desc: String)
}

// FIXME packages not lib | binary 
// web | node | lib

const help_cmds = [
  HelpCmd(name: "help", desc: "Print this help message"),
  HelpCmd(name: "init", desc: "Initialize a new JS project"),
  HelpCmd(
    name: "log",
    desc: "Print the program log file; only works if --keep-logs option was used with init",
  ),
  HelpCmd(name: "version", desc: "Print version and quit"),
]

const help_opts = [
  HelpOpt(
    name: "lib",
    desc: "Initialize a new library package, default is binary, which is a package that runs on the browser with a frontend",
    arg: option.None,
  ),
  HelpOpt(
    name: "no tests",
    desc: "Don't add testing dependencies (vitest)",
    arg: option.None,
  ),
  HelpOpt(
    name: "no docs",
    desc: "Don't add documentation dependency package (typedoc)",
    arg: option.None,
  ),
  HelpOpt(
    name: "no git",
    desc: "Dont't intialize a new git repo in the project dir",
    arg: option.None,
  ),
  HelpOpt(
    name: "log level",
    desc: "Controls the level of outputted logging details while the init command is running",
    arg: option.Some("level"),
  ),
  HelpOpt(
    name: "keep logs",
    desc: "Writes the init command logs to a HEBI_LOG file",
    arg: option.None,
  ),
  HelpOpt(
    name: "install server",
    desc: "Generate a simple server binary, in case it is needed for development. The server can be run with pnpm run server.If no port number is provided, port 7365 is used",
    arg: option.Some("port"),
  ),
  HelpOpt(
    name: "install deps",
    desc: "Actually install the npm dependencies. Default is to only edit the package.json file",
    arg: option.None,
  ),
]

fn help_message(
  desc: String,
  usage: String,
  cmds: List(HelpCmd),
  opts: List(HelpOpt),
) -> String {
  desc
  |> string.append("\n\n")
  |> string.append(colorize("Usage:", green))
  |> string.append(colorize(usage <> "\n\n", rose))
  |> string.append(colorize("Commands:\n", green))
  |> string.append({
    cmds
    |> list.map(fn(cmd) -> String {
      colorize("   " <> cmd.name, rose)
      |> string.append(", ")
      |> string.append(colorize(
        cmd.name |> string.first() |> result.unwrap("?"),
        rose,
      ))
      |> string.append("\t\t" <> cmd.desc)
    })
    |> list.reduce(fn(acc, s) -> String { acc <> "\n" <> s })
    |> result.unwrap("?")
  })
  |> string.append(colorize("\n\nOptions:init\n", green))
  |> string.append({
    opts
    |> list.map(fn(opt) -> String {
      fmt_opt_name_arg(opt.name, opt.arg)
      |> string.append(fmt_opt_desc(opt.desc, 16, 3))
    })
    |> list.reduce(fn(acc, s) -> String { acc <> "\n" <> s })
    |> result.unwrap("?")
  })
}

fn fmt_opt_name_short(name: String) -> String {
  "-"
  <> {
    name
    |> string.trim()
    |> string.split(" ")
    |> list.index_map(fn(s, i) -> String {
      case i == 0 {
        True -> s
        False -> s |> string.capitalise()
      }
      |> string.first()
      |> result.unwrap("?")
    })
    |> list.reduce(fn(acc, s) -> String { acc <> s })
    |> result.unwrap("?")
  }
}

fn fmt_opt_name(name: String) -> String {
  colorize("--" <> name |> string.trim() |> string.replace(" ", "-"), rose)
  <> ", "
  |> string.append(colorize(name |> fmt_opt_name_short(), rose))
}

fn fmt_opt_name_arg(name: String, arg: option.Option(String)) -> String {
  fmt_opt_name(name)
  |> string.append(case arg {
    option.None -> {
      ""
    }
    option.Some(arg) -> " " <> colorize("<" <> arg <> ">", rose)
  })
}

fn fmt_opt_desc(desc: String, max: Int, tabs: Int) -> String {
  let diff = max - { desc |> string.length() }
  string.repeat(" ", diff)
  |> string.append(string.repeat("\t", tabs))
  |> string.append(desc)
}

const help_message_const = "
Javascript project initializer

Usage:   hebi [COMMAND] [OPTIONS]

Commands:
   help, h   	Print this help message 
   init, i		Initialize a new JS project
   log, l		Print the program log file; only works if --keep-logs option was used with init
   version, v	Print version and quit

Options:init
 --lib, -L				Initialize a new library package, default is binary, which is a 
						 package that runs on the browser with a frontend
 --no-tests, -nT		Don't add testing dependencies (pywright, )
 --no-docs, -nD			Don't add documentation dependency package (typedoc)
 --no-git, -nG			Dont't intialize a new git repo in the project dir
 --install-server,		Generate a simple server binary, in case it is needed for
   -S <port>             development. The server can be run with pnpm run server.
						 If no port number is provided, port 7365 is used
 --log-level,			Controls the level of the logs printed to stdout while
	-lL <level>			 the init command is running
 --keep-logs, -kL		Save a HEBI_LOG log file the details the init COMMAND
 --install-deps, -iD	Actually install the npm dependencies, 
						 default is to only edit the package.json file
"

/// prints the help message and exits
/// gets called when the `help` cli command is ran
pub fn help() {
  io.println(help_message(
    "A javascript project intializer",
    " hebi [COMMAND] [OPTIONS]",
    help_cmds,
    help_opts,
  ))
}

// TODO error handling 
/// returns the package version from the gleam.toml file 
fn parse_version() -> String {
  "hebi "
  <> simplifile.read("gleam.toml")
  |> result.unwrap("")
  |> string.drop_start(31)
  |> string.split(on: "\"")
  |> list.first()
  |> result.unwrap("VER?")
}

/// prints the app version and exits
/// gets called when the `version` cli command is ran
pub fn version() {
  io.println(parse_version())
}

/// inits a new js project repo using the given Runner
/// gets called by the cli command `init [OPTIONS]`
pub fn init(runner: Runner) {
  todo
}

/// prints the init logs file that was saved during the operation, if any 
/// gets called by the cli command `log`
fn read_logs() {
  simplifile.read(".HEBI_LOG")
  |> result.unwrap(
    ".HEBI_LOG file was not found, did you run hebi init while using the --keep-logs flag",
  )
}

pub fn log() {
  io.print(read_logs())
}

pub type CLIOption {
  Library
  NoDocs
  NoTests
  InstallServer(Int)
  LogLevel(String)
  InstallDeps
  KeepLogs
}

pub type PackageKind {
  Lib
  Bin
  // a library package 
  // Lib
  // a web front end application
  // Web
  // a node (or whatever js runtime) application 
  // Node
}

pub type Dependency {
  TypeDoc
  TypeScript
  Rollup
  PlayWright
  PostCSSPlus
}

pub type Runner {
  Runner(
    install_server: Bool,
    server_port: Int,
    package: PackageKind,
    deps: List(Dependency),
    install_deps: Bool,
    log_level: String,
    keep_logs: Bool,
  )
}

fn resolve_runner_fields(data: InitData) -> Runner {
  let rnr = default_runner
  case data {
    Opts(byte) -> {
      resolve_runner_opts(0x1, byte, rnr)
    }
    OptsWithArgs(opts, args) -> {
      resolve_runner_opts_args(0x1, opts, args, rnr)
    }
    InitErr(e) -> {
      io.debug(e)

      panic as "bad desu yo"
    }
  }
}

fn resolve_runner_opts(mask: Int, opts: Int, rnr: Runner) -> Runner {
  case opts == 0 || mask == 128 {
    True -> rnr
    False -> {
      let rnr = case opts |> int.bitwise_and(mask) {
        1 -> opts_lib(rnr)
        2 -> opts_no_tests(rnr)
        4 -> opts_no_docs(rnr)
        // 8 -> opts_install_server(rnr, )
        16 -> opts_install_deps(rnr)
        // 32 -> opts_log_level(rnr, )
        bit ->
          panic as { "unreachable, got bit value " <> bit |> int.to_string() }
      }
      mask |> int.bitwise_shift_left(1) |> resolve_runner_opts(opts, rnr)
    }
  }
}

fn resolve_runner_opts_args(
  mask: Int,
  opts: Int,
  args: Dict(String, String),
  rnr: Runner,
) -> Runner {
  case mask |> int.bitwise_and(128) == 0 {
    False -> rnr
    True -> {
      case opts |> int.bitwise_and(mask) {
        1 -> opts_lib(rnr)
        2 -> opts_no_tests(rnr)
        4 -> opts_no_docs(rnr)
        8 ->
          opts_install_server(
            rnr,
            args
              |> dict.get("server-port")
              |> result.unwrap("7365")
              |> int.parse()
              |> result.unwrap(7365),
          )
        16 -> opts_install_deps(rnr)
        32 ->
          opts_log_level(
            rnr,
            args |> dict.get("log-level") |> result.unwrap("TRACE"),
          )
        _ -> panic as "unreachable"
      }
      mask
      |> int.bitwise_shift_left(1)
      |> resolve_runner_opts_args(opts, args, rnr)
    }
  }
}

fn opts_lib(rnr: Runner) -> Runner {
  Runner(
    deps: rnr.deps
      |> list.filter(fn(dep) {
        [TypeScript, TypeDoc, PlayWright] |> list.contains(dep)
      }),
    install_server: False,
    server_port: rnr.server_port,
    log_level: rnr.log_level,
    package: Lib,
    install_deps: rnr.install_deps,
    keep_logs: rnr.keep_logs,
  )
}

fn opts_no_tests(rnr: Runner) -> Runner {
  Runner(
    deps: rnr.deps
      |> list.filter(fn(dep) { dep != PlayWright }),
    install_server: rnr.install_server,
    server_port: rnr.server_port,
    log_level: rnr.log_level,
    package: rnr.package,
    install_deps: rnr.install_deps,
    keep_logs: rnr.keep_logs,
  )
}

fn opts_no_docs(rnr: Runner) -> Runner {
  Runner(
    deps: rnr.deps
      |> list.filter(fn(dep) { dep != TypeDoc }),
    install_server: rnr.install_server,
    server_port: rnr.server_port,
    log_level: rnr.log_level,
    package: rnr.package,
    install_deps: rnr.install_deps,
    keep_logs: rnr.keep_logs,
  )
}

fn opts_install_server(rnr: Runner, port: Int) -> Runner {
  Runner(
    deps: rnr.deps,
    install_server: True,
    server_port: port,
    log_level: rnr.log_level,
    package: rnr.package,
    install_deps: rnr.install_deps,
    keep_logs: rnr.keep_logs,
  )
}

fn opts_log_level(rnr: Runner, llv: String) -> Runner {
  Runner(
    deps: rnr.deps,
    install_server: rnr.install_server,
    server_port: rnr.server_port,
    log_level: llv,
    package: rnr.package,
    install_deps: rnr.install_deps,
    keep_logs: rnr.keep_logs,
  )
}

fn opts_keep_logs(rnr: Runner) -> Runner {
  Runner(
    deps: rnr.deps,
    install_server: rnr.install_server,
    server_port: rnr.server_port,
    log_level: rnr.log_level,
    package: rnr.package,
    install_deps: rnr.install_deps,
    keep_logs: True,
  )
}

fn opts_install_deps(rnr: Runner) -> Runner {
  Runner(
    deps: rnr.deps,
    install_server: rnr.install_server,
    server_port: rnr.server_port,
    log_level: rnr.log_level,
    package: rnr.package,
    install_deps: True,
    keep_logs: rnr.keep_logs,
  )
}

/// runs the cli program
/// executes the given command 
pub fn run(cmd: CLICommand) {
  case cmd {
    Help -> help()
    Version -> version()
    Log -> log()
    Init(data) -> {
      case data {
        option.Some(data) -> data |> resolve_runner_fields()
        option.None -> default_runner
      }
      |> init()
    }
  }
}

const default_runner = Runner(
  install_server: False,
  server_port: 7365,
  log_level: "QUIET",
  package: Bin,
  deps: [TypeScript, Rollup, PostCSSPlus, TypeDoc, PlayWright],
  install_deps: False,
  keep_logs: False,
)

fn full_runner() -> Runner {
  Runner(
    install_server: True,
    server_port: 7365,
    log_level: "TRACE",
    package: Bin,
    deps: [TypeScript, Rollup, PostCSSPlus, TypeDoc, PlayWright],
    install_deps: True,
    keep_logs: False,
  )
}

type LogLevel {
  Warn
  Debug
  Trace
  Error
  Info
  Fatal
  Quiet
}
