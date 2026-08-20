-- Copyright (c) 2026 Paul Butcher. All rights reserved.
-- Released under Apache 2.0 license as described in the file LICENSE.

module

import Leancurl
import Plausible

public section

open Leancurl Plausible

namespace Properties

/-- One header block as curl's `HEADERFUNCTION` delivers it: a status line, the header
lines, then a blank separator. A redirected request produces one block per hop. -/
private def renderBlock (hs : Headers) : String :=
  "HTTP/1.1 200 OK\r\n" ++ String.join (hs.map fun (k, v) => s!"{k}: {v}\r\n") ++ "\r\n"

private def lacks (needle s : String) : Bool := (s.splitOn needle).length == 1

/-- A name carrying the `": "` separator is not recoverable, and neither part may embed
the line terminator; outside those cases the round-trip is expected to hold exactly. -/
private def wellFormed (kv : String × String) : Bool :=
  lacks ": " kv.1 && lacks "\r\n" kv.1 && lacks "\r\n" kv.2

/-- The alphabet holds the characters the parser has to reason about, so that colons,
`": "` runs, and stray carriage returns arise by chance rather than by construction. -/
private def alphabet : List Char := ['a', 'B', '-', '0', ' ', ':', ';', '\r', '\n']

private def genHeaders : Gen Headers := do
  let token := do return String.ofList (← Gen.listOf (Gen.elements alphabet (by decide)))
  let hs ← Gen.listOf (Gen.prodOf token token)
  return hs.filter wellFormed

/-- A theorem was preferred here but `String.splitOn` neither reduces in the kernel, so
`decide` gets stuck, nor carries the lemmas an induction over the rendered block would
need, so the claim is checked by random sampling instead. -/
def checkHeaderRoundTrip (iterations : Nat := 200) : IO Unit := do
  for i in [0:iterations] do
    let first ← Gen.run genHeaders (i % 12)
    let second ← Gen.run genHeaders (i % 7)
    let parsed := Response.parseHeaders (renderBlock first ++ renderBlock second)
    unless parsed == first ++ second do
      throw <| IO.userError
        s!"parseHeaders round-trip failed for {repr (first ++ second)}, got {repr parsed}"

end Properties
