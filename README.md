# leancurl

A Lean 4 binding to [libcurl](https://curl.se/libcurl/), in two layers:

- `Leancurl.Easy`: a thin, mostly 1:1 binding to libcurl's easy interface (`curl_easy_init`/`setopt`/`perform`/...).
- `Leancurl.Curl`: an idiomatic wrapper on top, built on `Easy`.

## Usage

```lean
import Leancurl

open Leancurl

def main : IO Unit := do
  match ← Curl.get "https://example.com" with
  | .error e => IO.eprintln s!"request failed: {e.message}"
  | .ok resp => IO.println s!"status: {resp.status}, {resp.body.size} bytes"
```

`Curl.post`, `Curl.put`, and `Curl.delete` are also available, or build a `Request` directly and call `Curl.send` for full control over method, headers, body, timeout, and redirect handling.

## Development

```
lake build
lake test
```

Requires `libcurl` and `pkg-config` to be available on the system (discovered via `pkg-config` at build time).

The tests live in [`test/`](test), a separate package that requires this one by path, so that nothing they depend on reaches a downstream consumer. `lake test` at the root runs them.
