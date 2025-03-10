import gleam/dict
import gleam/dynamic/decode
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/json
import gleam/result

// DOCS the registry api 
// https://github.com/npm/registry/blob/main/docs/REGISTRY-API.md#get-v1search
const registry = "https://registry.npmjs.org/"

// fetches the metadata of a package version from the registry
// always fetches the latest version
pub fn fetch_package_meta(name: String) -> Result(String, httpc.HttpError) {
  let assert Ok(req) = request.to(registry <> name <> "/latest")

  let req = request.prepend_header(req, "accept", "application/json")

  // resp is a result response, httpcerror
  // result try changes the type of the ok value of the result it takes 
  // but not the type of the error value 
  // so the only error that can be returned is a httpcerror
  use resp <- result.try(httpc.send(req))
  case resp.status, resp |> response.get_header("content-type") {
    200, Ok("application/json") -> Ok(resp.body)
    _, _ -> Ok("bad response not json or not 200 Ok status code")
  }
}

// fetches the metadata of the specified package version from the registry
pub fn fetch_package_version_meta(
  name: String,
  version: String,
) -> Result(String, httpc.HttpError) {
  let assert Ok(req) = request.to(registry <> name <> "/" <> version)

  let req = request.prepend_header(req, "accept", "application/json")

  // resp is a result response, httpcerror
  // result try changes the type of the ok value of the result it takes 
  // but not the type of the error value 
  // so the only error that can be returned is a httpcerror
  use resp <- result.try(httpc.send(req))
  case resp.status, resp |> response.get_header("content-type") {
    200, Ok("application/json") -> Ok(resp.body)
    _, _ -> Ok("bad response not json or not 200 Ok status code")
  }
}

// parses the package_meta string into a Json 
pub fn parse_package_meta(pack: String) -> a {
  todo
}

// steps of downloading a package: 
// 1 - fetch metadata
// 2 - download the tarball at metadata.dist.tarball 
// 3 - unzip package and put it in ./node_modules/package_name 
// NOTE pnpm adds an empty node_modules dir to the package, as in: 
// ./node_modules/package_name/node_modules
// not sure what that is for or if I should replicate that behavior 

type Json {
  Num(Int)
  Str(String)
  Map(map: dict.Dict(String, Json))
  Arr(arr: List(Json))
  Bool(Bool)
}
