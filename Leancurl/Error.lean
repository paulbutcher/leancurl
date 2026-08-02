-- Copyright (c) 2026 Paul Butcher. All rights reserved.
-- Released under Apache 2.0 license as described in the file LICENSE.

import Leancurl.FFI

namespace Leancurl

/-- A libcurl `CURLcode` and its associated message. -/
structure CurlError where
  code : UInt32
  message : String
deriving Repr

namespace CurlError

def ofCode (code : UInt32) : CurlError :=
  { code, message := Easy.strerror code }

-- Stable across libcurl versions: `CURLcode` values are part of curl's public ABI contract.
def operationTimedOut : UInt32 := 28

end CurlError
end Leancurl
