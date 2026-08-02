-- Copyright (c) 2026 Paul Butcher. All rights reserved.
-- Released under Apache 2.0 license as described in the file LICENSE.

import Leancurl.FFI
import Leancurl.Error
import Leancurl.Types

namespace Leancurl

namespace Response

-- Curl's `HEADERFUNCTION` delivers the status line and a blank separator line
-- alongside the headers; both are colon-free (or empty) and so are dropped here
-- by `parseLine` returning `none`. On a redirected request it also delivers one
-- such block per hop, which this flattens into a single list.
private def parseLine (line : String) : Option (String × String) :=
  match line.splitOn ": " with
  | k :: v :: rest => some (k, ": ".intercalate (v :: rest))
  | _ => none

def parseHeaders (raw : String) : Headers :=
  raw.splitOn "\r\n" |>.filterMap parseLine

end Response

namespace Curl

def send (req : Request) : IO (Except CurlError Response) := do
  let h ← Easy.init
  Easy.setUrl h req.url
  unless req.method == .get do
    Easy.setMethod h req.method.toVerb
  unless req.headers.isEmpty do
    Easy.setHeaders h (req.headers.map fun (k, v) => s!"{k}: {v}").toArray
  if let some body := req.body then
    Easy.setPostFields h body
  if let some ms := req.timeoutMs then
    Easy.setTimeoutMs h ms
  Easy.setFollowLocation h req.followRedirects
  let code ← Easy.perform h
  if code != 0 then
    return .error (CurlError.ofCode code)
  let status ← Easy.getResponseCode h
  let body ← Easy.getResponseBody h
  let headersRaw ← Easy.getResponseHeadersRaw h
  return .ok { status, headers := Response.parseHeaders headersRaw, body }

def get (url : String) (headers : Headers := []) : IO (Except CurlError Response) :=
  send { url, headers }

def post (url : String) (body : ByteArray) (headers : Headers := []) : IO (Except CurlError Response) :=
  send { url, method := .post, headers, body := some body }

def put (url : String) (body : ByteArray) (headers : Headers := []) : IO (Except CurlError Response) :=
  send { url, method := .put, headers, body := some body }

def delete (url : String) (headers : Headers := []) : IO (Except CurlError Response) :=
  send { url, method := .delete, headers }

end Curl
end Leancurl
