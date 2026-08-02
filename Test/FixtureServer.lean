-- Copyright (c) 2026 Paul Butcher. All rights reserved.
-- Released under Apache 2.0 license as described in the file LICENSE.

import Std.Internal.UV.TCP
import Std.Net

namespace Test.FixtureServer

open Std.Net
open Std.Internal.UV.TCP

/-- Builds a raw `HTTP/1.1` response with an explicit `Content-Length`, so curl
returns as soon as the body is read rather than waiting for the connection to
close. -/
def mkResponse (status : UInt32) (statusText : String)
    (headers : List (String × String)) (body : String) : ByteArray :=
  let bodyBytes := body.toUTF8
  let headerLines := headers ++ [("Content-Length", toString bodyBytes.size)]
  let head := s!"HTTP/1.1 {status} {statusText}\r\n" ++
    String.join (headerLines.map fun (k, v) => s!"{k}: {v}\r\n") ++ "\r\n"
  head.toUTF8 ++ bodyBytes

/-- Starts a one-shot HTTP server on loopback: accepts a single connection, reads
whatever the client sends, replies with `response`, and resolves the returned
promise with the raw bytes it received (so the caller can assert on the request
that was actually sent). -/
def startOnce (response : ByteArray) : IO (UInt16 × IO.Promise ByteArray) := do
  let sock ← Socket.new
  sock.bind (.v4 { addr := IPv4Addr.ofParts 127 0 0 1, port := 0 })
  sock.listen 1
  let port := (← sock.getSockName).port
  let received ← IO.Promise.new (α := ByteArray)
  let _ ← IO.asTask do
    match (← sock.accept).result!.get with
    | .error _ => received.resolve ByteArray.empty
    | .ok conn =>
      let request ← match (← conn.recv? 65536).result!.get with
        | .error _ | .ok none => pure ByteArray.empty
        | .ok (some bytes) => pure bytes
      let _ := (← conn.send #[response]).result!.get
      received.resolve request
  return (port, received)

end Test.FixtureServer
