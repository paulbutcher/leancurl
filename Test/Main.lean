-- Copyright (c) 2026 Paul Butcher. All rights reserved.
-- Released under Apache 2.0 license as described in the file LICENSE.

import Leancurl
import Test.FixtureServer

open Leancurl

def assertEq [BEq α] [Repr α] (what : String) (expected actual : α) : IO Unit := do
  unless expected == actual do
    throw <| IO.userError s!"{what}: expected {repr expected}, got {repr actual}"

def testVersion : IO Unit := do
  let v ← Leancurl.version
  unless v.startsWith "libcurl/" do
    throw <| IO.userError s!"unexpected curl_version output: {v}"

def testFileUrl : IO Unit := do
  let path ← IO.FS.realPath "Test/fixtures/hello.txt"
  let h ← Easy.init
  Easy.setUrl h s!"file://{path}"
  let code ← Easy.perform h
  assertEq "perform CURLcode" (0 : UInt32) code
  let body ← Easy.getResponseBody h
  let expected ← IO.FS.readBinFile path
  unless expected == body do
    throw <| IO.userError s!"response body mismatch: expected {expected.size} bytes, got {body.size}"

def testClientGetFileUrl : IO Unit := do
  let path ← IO.FS.realPath "Test/fixtures/hello.txt"
  let expected ← IO.FS.readBinFile path
  match ← Curl.get s!"file://{path}" with
  | .error e => throw <| IO.userError s!"Curl.get failed: {e.message}"
  | .ok resp =>
    unless expected == resp.body do
      throw <| IO.userError
        s!"response body mismatch: expected {expected.size} bytes, got {resp.body.size}"

def testClientGetHttp : IO Unit := do
  let response := Test.FixtureServer.mkResponse 200 "OK"
    [("X-Fixture", "hello")] "greetings"
  let (port, _received) ← Test.FixtureServer.startOnce response
  match ← Curl.get s!"http://127.0.0.1:{port}/" [("X-Request", "leancurl")] with
  | .error e => throw <| IO.userError s!"Curl.get failed: {e.message}"
  | .ok resp =>
    assertEq "status" (200 : UInt32) resp.status
    unless (String.fromUTF8! resp.body) == "greetings" do
      throw <| IO.userError s!"unexpected body: {String.fromUTF8! resp.body}"
    unless resp.headers.any (·.1 == "X-Fixture") do
      throw <| IO.userError s!"missing X-Fixture header, got: {repr resp.headers}"

def testClientPostHttp : IO Unit := do
  let response := Test.FixtureServer.mkResponse 201 "Created" [] ""
  let (port, received) ← Test.FixtureServer.startOnce response
  let body := "payload=42".toUTF8
  match ← Curl.post s!"http://127.0.0.1:{port}/items" body [("Content-Type", "application/x-www-form-urlencoded")] with
  | .error e => throw <| IO.userError s!"Curl.post failed: {e.message}"
  | .ok resp =>
    assertEq "status" (201 : UInt32) resp.status
    let requestText := String.fromUTF8! received.result!.get
    unless requestText.startsWith "POST /items" do
      throw <| IO.userError s!"unexpected request line: {requestText.takeWhile (· ≠ '\r')}"
    unless (requestText.splitOn "\r\n\r\n").getLast! == "payload=42" do
      throw <| IO.userError s!"unexpected request body: {requestText}"

def main : IO Unit := do
  testVersion
  testFileUrl
  testClientGetFileUrl
  testClientGetHttp
  testClientPostHttp
  IO.println "All tests passed."
