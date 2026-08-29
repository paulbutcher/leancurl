-- Copyright (c) 2026 Paul Butcher. All rights reserved.
-- Released under Apache 2.0 license as described in the file LICENSE.

module

import Std.Internal.UV.TCP
import Std.Net

public section

namespace FixtureServer

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

/-- A body far past curl's per-callback maximum, so the response reaches the shim in
many pieces. Each line names its own index, so a piece dropped, duplicated, or
reordered during reassembly fails a comparison rather than only changing the length. -/
def largeBody (lines : Nat) : String :=
  let pad := String.ofList (List.replicate 64 'x')
  String.join <| (List.range lines).map fun i => s!"line {i} {pad}\n"

/-- Blocks until `promise` resolves, treating an abandoned promise as a failure
rather than a panic. -/
def await (what : String) (promise : IO.Promise α) : IO α :=
  match promise.result?.get with
  | some a => pure a
  | none => throw <| IO.userError s!"{what}: promise was dropped without a result"

/-- Starts a one-shot HTTP server on loopback: accepts a single connection, reads
whatever the client sends, replies with `response`, and resolves the returned
promise with the raw bytes it received (so the caller can assert on the request
that was actually sent). -/
def startOnce (response : ByteArray) : IO (UInt16 × IO.Promise (Except String ByteArray)) := do
  let sock ← Socket.new
  sock.bind (.v4 { addr := IPv4Addr.ofParts 127 0 0 1, port := 0 })
  sock.listen 1
  let port := (← sock.getSockName).port
  let received ← IO.Promise.new (α := Except String ByteArray)
  -- Every path resolves `received` exactly once, and a failure resolves it with its
  -- own cause: a server that never got the request must not read as a client that
  -- sent nothing.
  let _ ← IO.asTask do
    let result ←
      try
        match ← await "accept" (← sock.accept) with
        | .error e => pure (.error s!"accept: {e}")
        | .ok conn =>
          match ← await "recv" (← conn.recv? 65536) with
          | .error e => pure (.error s!"recv: {e}")
          | .ok none => pure (.error "recv: connection closed before any request bytes")
          | .ok (some bytes) =>
            match ← await "send" (← conn.send #[response]) with
            | .error e => pure (.error s!"send: {e}")
            | .ok () => pure (.ok bytes)
      catch e => pure (.error (toString e))
    received.resolve result
  return (port, received)

/-- The request bytes the server received, reporting whatever stopped it from
receiving them. -/
def request (received : IO.Promise (Except String ByteArray)) : IO ByteArray := do
  match ← await "request" received with
  | .ok bytes => pure bytes
  | .error e => throw <| IO.userError s!"fixture server: {e}"

end FixtureServer
