# hebidaruma

[![Package Version](https://img.shields.io/hexpm/v/hebidaruma)](https://hex.pm/packages/hebidaruma)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/hebidaruma/)

```sh
gleam add hebidaruma@1
```
```gleam
import hebidaruma

pub fn main() {
  // TODO: An example of the project in use
}
```

Further documentation can be found at <https://hexdocs.pm/hebidaruma>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

hebidaruma is a cli tool for initializing javascript project directories.
I wrote it because afaik none of the existing js package managers (npm, pnpm, bun, yaml) allow the user to customize the behavior of the npm init command. 
I wrote a shell script at first, but it started getting too big, so I made this cli tool, its in gleam as an exercise since I wanna learn the language.
