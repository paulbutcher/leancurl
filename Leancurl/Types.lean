-- Copyright (c) 2026 Paul Butcher. All rights reserved.
-- Released under Apache 2.0 license as described in the file LICENSE.

module

public section

namespace Leancurl

inductive Method
  | get
  | post
  | put
  | delete
  | patch
  | head
  | custom (verb : String)
deriving Repr, BEq

namespace Method

-- Exposed so that downstream code can reason about the verb a method puts on the wire.
@[expose] def toVerb : Method → String
  | .get => "GET"
  | .post => "POST"
  | .put => "PUT"
  | .delete => "DELETE"
  | .patch => "PATCH"
  | .head => "HEAD"
  | .custom verb => verb

end Method

abbrev Headers := List (String × String)

structure Request where
  url : String
  method : Method := .get
  headers : Headers := []
  body : Option ByteArray := none
  timeoutMs : Option UInt32 := none
  followRedirects : Bool := true

structure Response where
  status : UInt32
  headers : Headers
  body : ByteArray

end Leancurl
