import gleam/dict
import gleam/dynamic/decode
import gleam/float.{parse}
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string

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

pub fn parse_chars(parser: JsonParser) -> Json {
  // io.print("jsonlen: ")
  // io.debug(parser.json |> list.length())
  // io.print("strlen: ")
  // io.debug(parser.str |> list.length())
  // io.print("templen: ")
  // io.debug(parser.temp.val |> string.length())
  // io.print("tempkind: ")
  // io.debug(parser.temp.kind)
  // io.print("tempval: ")
  // io.debug(parser.temp.val)
  io.println("parser json is")
  {
    use json <- list.map(parser.json)
    io.debug(json)
  }
  io.println("")
  io.println("temp=<" <> parser.temp.val <> ">")
  io.println("")
  io.println("char=<" <> parser.str |> list.first() |> result.unwrap("") <> ">")
  io.println("	-----	")

  case parser.str |> list.is_empty() {
    True ->
      parser.json
      |> list.first()
      |> result.unwrap(JsonParseItem(Map(dict.new()), 0))
      |> item_json()
      |> json_filter_dummy()
    False -> {
      // get the chars with/o the first char 
      let str = parser.str |> list.rest() |> result.unwrap([])

      case parser.str |> list.first() |> result.unwrap("") {
        "{" -> {
          parser
          |> parser_json(
            parser.json
            |> list.append([
              JsonParseItem(
                Map(dict.new()),
                parser |> parser_max_nest_or_next(),
              ),
            ]),
          )
        }
        "[" -> {
          parser
          |> parser_json(
            parser.json
            |> list.append([
              JsonParseItem(
                Arr(list.new()),
                parser |> parser_max_nest_or_next(),
              ),
            ]),
          )
        }
        // "}" | "]" -> {
        //   let #(p, coll) = collection_push(parser, [])
        //
        //   p |> collect(coll)
        // }
        ch -> parser |> match_char(ch)
      }
      |> parser_str(str)
      |> parse_chars()
    }
  }
}

// parses the package_meta string into a Json 
// uses words
pub fn parse_package_meta1(words: List(String)) -> Json {
  todo
}

// steps of downloading a package: 
// 1 - fetch metadata
// 2 - download the tarball at metadata.dist.tarball 
// 3 - unzip package and put it in ./node_modules/package_name 
// NOTE pnpm adds an empty node_modules dir to the package, as in: 
// ./node_modules/package_name/node_modules
// not sure what that is for or if I should replicate that behavior 

fn next_pat(pat: String) -> option.Option(String) {
  case pat {
    "{" -> option.Some("}")
    "}" -> option.Some("[")
    "[" -> option.Some("]")
    "]" -> option.Some(",")
    ":" -> option.Some(",")
    "," -> option.None
    _ -> panic as "bakana"
  }
}

pub type Json {
  Int(Int)
  Flt(Float)
  Str(String)
  Map(map: dict.Dict(String, Json))
  Arr(arr: List(Json))
  Bool(Bool)
  Null
}

pub type JsonParser {
  JsonParser(json: List(JsonParseItem), str: List(String), temp: JsonParseValue)
}

pub fn new_parser(str: String) {
  JsonParser(list.new(), str |> string.to_graphemes(), JsonParseValue("", 0))
}

// returns a default first parse item of a json object data: JsonParseItem(dict.new(), 0)
fn item0() {
  JsonParseItem(Map(dict.new()), 0)
}

// returns the nest of the last json item in the json parser struct 
// if parser has no items returns 0
fn parser_max_nest(parser: JsonParser) -> Int {
  parser.json |> list.last() |> result.unwrap(item0()) |> item_nest()
}

// returns the nest of the next item in the json items 
fn parser_max_nest_or_next(parser: JsonParser) -> Int {
  let item = parser.json |> list.last() |> result.unwrap(item0())
  case item |> item_json() |> json_to_u8() {
    0 | 1 | 2 | 4 -> item |> item_nest()
    8 | 16 ->
      case item |> item_arr_or_map_is_empty() {
        True -> { item |> item_nest() } + 1
        False -> item |> item_nest()
      }
    val ->
      panic as {
        "value "
        <> val |> int.to_string()
        <> " was not hard coded in json u8 represnetation"
      }
  }
}

// returns wether the arr or map is yet to be filled 
fn item_arr_or_map_is_empty(item: JsonParseItem) {
  case item.item {
    Arr(a) -> { a |> list.length() } == 0
    Map(m) -> { m |> dict.size() } == 0
    _ -> panic as "p199, expected arr or map here"
  }
}

// updates the JsonParser json field and returns the JsonParser
fn parser_json(parser: JsonParser, json: List(JsonParseItem)) {
  JsonParser(json, parser.str, parser.temp)
}

fn parser_json_plus(parser: JsonParser, item: JsonParseItem) {
  JsonParser(parser.str, parser.temp, json: parser.json |> list.append([item]))
}

// updates the JsonParser str field and returns the JsonParser
fn parser_str(parser: JsonParser, str: List(String)) -> JsonParser {
  JsonParser(json: parser.json, str: str, temp: parser.temp)
}

// updates the JsonParser temp field's val field
// and returns the JsonParser
fn parser_temp_val(parser: JsonParser, val: String) -> JsonParser {
  JsonParser(
    json: parser.json,
    str: parser.str,
    temp: parser.temp |> temp_val(val),
  )
}

fn parser_temp(parser: JsonParser, temp: JsonParseValue) {
  JsonParser(temp, json: parser.json, str: parser.str)
}

// updates the JsonParser temp field's kind field
// and returns the JsonParser
fn parser_temp_kind(parser: JsonParser, kind: Int) {
  JsonParser(
    json: parser.json,
    str: parser.str,
    temp: parser.temp |> temp_kind(kind),
  )
}

pub type JsonParseItem {
  JsonParseItem(item: Json, nest: Int)
}

fn item_json(item: JsonParseItem) -> Json {
  item.item
}

fn item_nest(item: JsonParseItem) {
  item.nest
}

fn json_filter_dummy(json: Json) -> Json {
  case json {
    Map(map) ->
      {
        map
        |> dict.map_values(fn(k, v) {
          case v |> json_to_u8() {
            16 | 8 -> json_filter_dummy(v)
            _ -> v
          }
        })
        |> dict.filter(fn(k, v) { k != "Dummy" })
      }
      |> map_from_dict()
    Arr(arr) ->
      {
        arr
        |> list.map(fn(v) {
          case v |> json_to_u8() {
            16 | 8 -> json_filter_dummy(v)
            _ -> v
          }
        })
        |> list.filter(fn(v) { v != Str("Dummy") })
      }
      |> arr_from_list()
    _ -> panic as "p264, expected map or arr"
  }
}

// temporary holder for json token chunks 
// the kind indicates what the val field string should be parsed into 
// 
pub type JsonParseValue {
  JsonParseValue(val: String, kind: Int)
}

// updates the JsonParseValue's val field
// and returns the JsonParseValue
fn temp_val(temp: JsonParseValue, val: String) {
  JsonParseValue(val, kind: temp.kind)
}

fn temp_val_plus(temp: JsonParseValue, val: String) {
  // io.println("1temp val is")
  // io.debug(temp.val)
  JsonParseValue(val: temp.val <> val, kind: temp.kind)
}

// updates the JsonParseValue's val field
// and returns the JsonParseValue
fn temp_kind(temp: JsonParseValue, kind: Int) {
  JsonParseValue(kind, val: temp.val)
}

// used when a closing char is reached, i.e., '}', ']'. 
// collects the last items in the json field until it meets a decrementation in nest level
fn collect(parser: JsonParser, collection: List(JsonParseItem)) -> JsonParser {
  case parser.json |> list.last() {
    Ok(item) -> {
      // io.println("collect item is")
      // io.debug(item)
      case collection_last(collection) |> nests_eq(item) {
        // if nests of last pushed item and parser json last unpushed item are equal push again 
        True -> {
          let #(p, coll) = parser |> collection_push(collection)
          collect(p, coll)
        }
        // else found the wrapper arr/map 
        // append collection to item map / arr
        False ->
          case json_to_u8(item.item) {
            0 | 1 | 2 | 4 | 32 ->
              panic as "p294, wrapper json turned out to be a value"
            8 -> {
              collection_arr(parser, collection)
            }
            16 -> {
              collection_map(parser, collection)
            }
            val ->
              panic as {
                "p304, no such value was coded in json values as u8: "
                <> val |> int.to_string()
              }
          }
      }
    }
    Error(e) ->
      panic as "p311, reached end of json items while collecting children of some wrapper (Map or Arr)"
  }
}

// returns the last item in the collection 
fn collection_last(coll: List(JsonParseItem)) {
  case coll |> list.last() {
    Ok(item) -> item
    Error(e) ->
      panic as "reached end of json items while collecting children of some wrapper (Map or Arr)\n"
  }
}

// returns the last item in the parser json field inside a 
// list to be passed to the collect function and 
// the json parser with the last json item removed
fn collection_push(parser: JsonParser, coll: List(JsonParseItem)) {
  case parser.json |> list.last() {
    // 
    Ok(item) -> #(
      parser
        |> parser_json(
          parser.json |> list.reverse() |> list.drop(1) |> list.reverse(),
        ),
      coll |> list.append([item]),
    )
    Error(e) ->
      panic as "reached end of json items while collecting children of some wrapper (Map or Arr)\n"
  }
}

// returns the corrected parser with the new filled array 
fn collection_arr(parser: JsonParser, coll: List(JsonParseItem)) {
  // io.println("collarr parser json is")
  // {
  // use json <- list.map(parser.json)
  // io.debug(json)
  // }
  // get nest of the array that should be filled
  let nest = case parser.json |> list.last() {
    Ok(item) -> item.nest
    Error(_) -> panic as "p332, parser json is empty"
  }
  // filter out nest from items collection to get json values 
  let coll = {
    use item <- list.map(coll)
    item.item
  }
  // remove the empty array from the json 
  // and push the filled array in
  let json =
    parser.json
    |> list.reverse()
    |> list.drop(1)
    |> list.prepend(JsonParseItem(Arr(arr: coll |> list.reverse()), nest))
    |> list.reverse()
  // return the parser with the corrected json 
  parser |> parser_json(json)
}

// BUG pushing float/int values to the json list 
// breaks the number 
// mosr likely caused by the exponent support 

// returns the corrected parser with the new filled array 
fn collection_map(parser: JsonParser, coll: List(JsonParseItem)) {
  // io.println("collmap parser json is")
  // {
  // use json <- list.map(parser.json)
  //   io.debug(json)
  // }
  // get nest of the map that should be filled
  let nest = case parser.json |> list.last() {
    Ok(item) -> item.nest
    Error(_) -> panic as "p361, parser json is empty"
  }
  // filter out nest from items collection to get json values 
  let coll = {
    coll
    |> list.reverse()
    |> list.sized_chunk(2)
    |> list.map(fn(pair) { pair |> pair_to_tuple() })
    |> dict.from_list()
  }
  // remove the empty array from the json 
  // and push the filled array in
  let json =
    parser.json
    |> list.reverse()
    |> list.drop(1)
    |> list.prepend(JsonParseItem(Map(map: coll), nest))
    |> list.reverse()
  // return the parser with the corrected json 
  parser |> parser_json(json)
}

// NOTE list.drop removes the first n elements, not the last 

fn nests_eq(item: JsonParseItem, other: JsonParseItem) {
  item.nest == other.nest
}

fn json_to_u8(json: Json) {
  case json {
    Str(_) -> 0
    Int(_) -> 1
    Flt(_) -> 2
    Bool(_) -> 4
    Arr(_) -> 8
    Map(_) -> 16
    Null -> 32
  }
}

fn pair_first_infallible(chunk: List(JsonParseItem)) {
  case chunk |> list.first() {
    Ok(item) -> item.item
    Error(e) -> panic as "this list absolutely has at least 1 item"
  }
}

fn pair_last_infallible(chunk: List(JsonParseItem)) {
  case chunk |> list.last() {
    Ok(item) -> item.item
    Error(e) -> panic as "this list absolutely has at least 1 item"
  }
}

fn pair_to_tuple(pair: List(JsonParseItem)) {
  #(
    case pair |> pair_first_infallible() {
      Str(s) -> s
      _ -> panic as "p413: expected string as key value got something else "
    },
    pair |> pair_last_infallible(),
  )
}

fn match_char(parser: JsonParser, char: String) -> JsonParser {
  case parser.temp.val |> string.is_empty() {
    True -> {
      case char {
        // in between values and wrappers 
        // return the parser right away 
        ":" | "," -> parser
        // end of wrapper, arr or map
        "}" | "]" -> {
          case parser.json |> list.last() {
            Ok(last) -> {
              case last.item |> json_to_u8() {
                0 | 1 | 2 | 4 | 32 -> {
                  let #(p, coll) = collection_push(parser, [])

                  p |> collect(coll)
                }
                8 | 16 -> {
                  case last |> item_arr_or_map_is_empty() {
                    // end of empty arr or map, do nothing since its empty, just return parser 
                    // BUG since I use empty arr or map to decide nesting levels 
                    // which in turn decide the parent of each value item
                    // passing an empty arr/map breaks the nesting and fills the empty
                    // arr/map with items that dont belong to it 
                    // HACK put dummy string value in the empty arr/map
                    True -> {
                      let #(p, coll) = collection_push(parser, [])

                      p |> populate_with_dummy(coll)
                    }
                    False -> {
                      let #(p, coll) = collection_push(parser, [])

                      p |> collect(coll)
                    }
                  }
                }
                _ ->
                  panic as "no such value written as a u8 repr for the json enum"
              }
            }
            Error(e) -> panic as "p473 items list can not be empty"
          }
        }
        // string value start 
        "\"" ->
          parser_temp(parser, parser.temp |> temp_val("\"") |> temp_kind(0))
        // bool value start 
        "t" | "f" ->
          parser_temp(parser, parser.temp |> temp_val(char) |> temp_kind(4))

        // int or float value start 
        // assume int at first 
        // if has '.' change to float 
        // if float has '.' thats a value error
        "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" | "0" -> {
          parser_temp(parser, parser.temp |> temp_val(char) |> temp_kind(1))
        }
        "n" ->
          parser_temp(parser, parser.temp |> temp_val(char) |> temp_kind(32))
        // ERROR: {} and  [] were already handled before this function was reached 
        // so we hit a value that is not of a json type 
        val -> panic as { "line 446 json is bad, val <" <> val <> ">" }
      }
    }
    False -> {
      case char {
        // in between values and wrappers 
        // do nothing different from a ch, just normal chars in a string value 
        // ":" | "," -> {
        //   todo
        // }
        // string value end 
        // or a string escape 
        // check last of temp to know for sure 
        "\"" ->
          case parser.temp.kind == 0 {
            True ->
              case parser.temp |> last_of_temp() == "\\" {
                // push val to json items 
                False ->
                  parser
                  |> parser_item_push(JsonParseItem(
                    item: parser.temp
                      |> temp_val_plus("\"")
                      |> json_from_parse_value(),
                    nest: parser |> parser_max_nest_or_next(),
                  ))
                // push char to val 
                True -> parser |> parser_temp(temp_val_plus(parser.temp, "\""))
              }
            False -> panic as "current value should have been an str"
          }
        "e" -> {
          case parser.temp |> temp_kind_is() {
            // push e to string value 
            0 -> {
              parser |> parser_temp(temp_val_plus(parser.temp, "e"))
            }
            // int or float value exponent
            // if the value already contains an e/E then bad json 
            1 | 2 -> {
              case parser.temp |> temp_num_is_exp() {
                False -> panic as "line 476json is bad"
                True -> parser |> parser_temp(temp_val_plus(parser.temp, "e"))
              }
            }
            // bool value end
            // push boolean to json items
            4 -> {
              parser
              |> parser_item_push(JsonParseItem(
                item: parser.temp
                  |> temp_val_plus("e")
                  |> json_from_parse_value(),
                nest: parser |> parser_max_nest_or_next(),
              ))
            }
            // ERROR arr or map cant even get into temp value
            8 | 16 ->
              panic as "unreachable, there is no way in the code for an arr or map to be in temp"
            val ->
              panic as {
                "value "
                <> val |> int.to_string()
                <> " was not hard coded in json u8 represnetation"
              }
          }
        }
        // int, float or str value push char
        "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" | "0" -> {
          case parser.temp.kind {
            0 | 1 | 2 -> parser |> parser_temp(temp_val_plus(parser.temp, char))
            _ -> panic as "digits can only be in str or num types"
          }
        }
        // int to float or bad float 
        // or str value char
        "." -> {
          case parser.temp.kind {
            0 -> parser |> parser_temp(temp_val_plus(parser.temp, "."))
            1 -> {
              parser |> parser_temp(parser.temp |> temp_int_to_flt())
            }
            2 -> panic as "value is already float, how could it contain 2 '.'"
            _ ->
              panic as "value is neither num nor str, '.' makes no sense here"
          }
        }
        // in or float exponent handling
        "E" | "-" | "+" -> {
          case parser.temp.kind {
            0 -> parser |> parser_temp(temp_val_plus(parser.temp, char))
            1 | 2 ->
              case parser.temp |> temp_num_is_exp() {
                True ->
                  panic as "line 529, number value already contains exponent notation, json is bad"
                False -> parser |> parser_temp(temp_val_plus(parser.temp, char))
              }
            _ ->
              panic as "',' cant be inside value that is neither string nor after number"
          }
        }
        // int or float value end 
        "," ->
          case parser.temp.kind {
            0 -> parser |> parser_temp(temp_val_plus(parser.temp, ","))
            1 | 2 -> {
              parser
              |> parser_item_push(JsonParseItem(
                item: parser.temp
                  |> json_from_parse_value(),
                nest: parser |> parser_max_nest_or_next(),
              ))
            }
            _ ->
              panic as "p579, ',' cant be inside value that is neither string nor number"
          }
        // or int or float end when at the end of an arr or a map 
        "}" | "]" -> {
          case parser.temp.kind {
            0 -> parser |> parser_temp(temp_val_plus(parser.temp, char))
            1 | 2 -> {
              io.println("pushing num to json items list")
              let p =
                parser
                |> parser_item_push(JsonParseItem(
                  item: parser.temp
                    |> json_from_parse_value(),
                  nest: parser |> parser_max_nest_or_next(),
                ))

              let #(p, coll) = collection_push(p, [])

              p |> collect(coll)
            }
            _ ->
              panic as "p579, ',' cant be inside value that is neither string nor number"
          }
        }
        // end of null
        "l" ->
          case parser.temp.kind {
            0 | 4 -> parser |> parser_temp(temp_val_plus(parser.temp, "l"))
            32 ->
              parser
              |> parser_item_push(JsonParseItem(
                item: parser.temp
                  |> temp_val_plus("l")
                  |> json_from_parse_value(),
                nest: parser |> parser_max_nest_or_next(),
              ))
            _ ->
              panic as "p594, 'l' cant be inside value that is neither string nor null or false"
          }

        ch -> parser |> parser_temp(temp_val_plus(parser.temp, ch))
      }
    }
  }
}

fn json_from_parse_value(temp: JsonParseValue) -> Json {
  case temp.kind {
    0 -> Str(temp.val)
    // 1 -> Int(temp.val |> parse_int_e())
    1 -> Int(temp.val |> int.parse() |> result.unwrap(0))
    // 2 -> Flt(temp.val |> parse_flt_e())
    2 -> Flt(temp.val |> float.parse() |> result.unwrap(0.0))
    4 -> Bool(temp.val |> parse_bool() |> result.unwrap(False))
    8 | 16 -> panic as "line 382, a temp value shouldnt be an arr or map"
    32 -> Null
    _ -> panic as "line 383, got impossible int value of json variant"
  }
}

fn parse_bool(bool: String) -> Result(Bool, String) {
  case bool {
    "true" -> Ok(True)
    "false" -> Ok(False)
    val -> Error(val)
  }
}

// pushes an item to the end of the parser json 
// and returns the updated parser 
// clears the temp
fn parser_item_push(parser: JsonParser, item: JsonParseItem) -> JsonParser {
  parser
  |> parser_json(
    parser.json
    |> list.reverse()
    // dropping here is a bug, that is only for wrappers like map and arr, since i first push 
    // an empy value of them to the json list
    // |> list.drop(1)
    |> list.prepend(item)
    |> list.reverse(),
  )
  |> parser_temp(new_temp())
}

fn new_temp() {
  JsonParseValue("", 0)
}

fn last_of_temp(temp: JsonParseValue) -> String {
  case temp.val |> string.last() {
    Ok(s) -> s
    Error(e) ->
      panic as "this function was called because temp val is not empty, so how come it is"
  }
}

fn temp_kind_is(temp: JsonParseValue) {
  temp.kind
}

// TODO int or float may be in the exponent form 

fn parse_int_e(val: String) -> Int {
  let split =
    val
    |> string.lowercase()
    |> string.split("e")
  let i =
    split
    |> list.first()
    |> result.unwrap("")
    |> int.parse()
    |> result.unwrap(0)

  let e =
    split
    |> list.last()
    |> result.unwrap("e")
    |> int.parse()
    |> result.unwrap(1)
    |> int.to_float()

  i
  * {
    10
    |> int.power(e)
    |> result.unwrap(1.0)
    |> float.round()
  }
}

fn parse_flt_e(val: String) -> Float {
  let split =
    val
    |> string.lowercase()
    |> string.split("e")

  let f =
    split
    |> list.first()
    |> result.unwrap("")
    |> float.parse()
    |> result.unwrap(0.0)

  let e =
    split
    |> list.last()
    |> result.unwrap("e")
    |> float.parse()
    |> result.unwrap(1.0)

  f *. 10.0 |> float.power(e) |> result.unwrap(0.0)
}

fn temp_num_is_exp(temp: JsonParseValue) -> Bool {
  temp.val
  |> string.to_graphemes()
  |> list.any(fn(c) { c == "e" || c == "E" })
}

fn temp_is_int_or_flt(temp: JsonParseValue) {
  temp.kind == 1 || temp.kind == 2
}

fn temp_int_to_flt(temp: JsonParseValue) {
  temp |> temp_val_plus(".") |> temp_kind(2)
}

// TODO should change the implementation to take tokens of 
// words separated by "{" "[" "}" "]" "," ":" 
// then build the json back up correctly from there 
// that would likely be more performant than iterating over the whole json chars

// BUG empty arr or map arent handled correctly 

fn populate_with_dummy(
  parser: JsonParser,
  coll: List(JsonParseItem),
) -> JsonParser {
  case coll |> list.last() {
    Ok(last) -> {
      parser
      |> parser_json_plus(JsonParseItem(
        case last.item {
          Str(_) | Int(_) | Flt(_) | Bool(_) | Null ->
            panic as "p808, this function should only be used on a [Map/Arr] list"
          Arr(a) -> a |> list.prepend(Str("Dummy")) |> arr_from_list()
          Map(m) -> m |> dict.insert("Dummy", Str("_")) |> map_from_dict()
        },
        last.nest,
      ))
    }
    Error(e) ->
      panic as "p805, this function should only be used on a [Map/Arr] list"
  }
}

fn arr_from_list(l: List(Json)) {
  Arr(arr: l)
}

fn map_from_dict(d: dict.Dict(String, Json)) {
  Map(map: d)
}
