-- Copyright (c) 2026 Paul Butcher. All rights reserved.
-- Released under Apache 2.0 license as described in the file LICENSE.

namespace Leancurl

@[extern "lean_curl_version"]
opaque version : IO String

namespace Easy

private opaque HandleImpl : NonemptyType.{0}

/-- An opaque `CURL*` easy-interface handle. -/
def Handle : Type := HandleImpl.type

instance : Nonempty Handle := HandleImpl.property

@[extern "lean_curl_global_init"]
private opaque globalInit : IO Unit

initialize globalInit

@[extern "lean_curl_easy_init"]
opaque init : IO Handle

@[extern "lean_curl_easy_set_url"]
opaque setUrl (h : @& Handle) (url : @& String) : IO Unit

/-- Sets `CURLOPT_CUSTOMREQUEST`. Combine with `setPostFields` to send a body with a
non-`GET` method: setting `CURLOPT_POSTFIELDS` is what makes libcurl actually send a
request body, and `CUSTOMREQUEST` only overrides the verb libcurl reports. -/
@[extern "lean_curl_easy_set_method"]
opaque setMethod (h : @& Handle) (method : @& String) : IO Unit

/-- Each entry is a raw `"Key: Value"` header line, as libcurl's `curl_slist` expects. -/
@[extern "lean_curl_easy_set_headers"]
opaque setHeaders (h : @& Handle) (headers : @& Array String) : IO Unit

@[extern "lean_curl_easy_set_post_fields"]
opaque setPostFields (h : @& Handle) (body : @& ByteArray) : IO Unit

@[extern "lean_curl_easy_set_timeout_ms"]
opaque setTimeoutMs (h : @& Handle) (ms : UInt32) : IO Unit

@[extern "lean_curl_easy_set_follow_location"]
opaque setFollowLocation (h : @& Handle) (follow : Bool) : IO Unit

/-- Performs the request and returns the raw `CURLcode` (`0` is success), matching
libcurl's own `curl_easy_perform` return value. -/
@[extern "lean_curl_easy_perform"]
opaque perform (h : @& Handle) : IO UInt32

@[extern "lean_curl_easy_get_response_code"]
opaque getResponseCode (h : @& Handle) : IO UInt32

@[extern "lean_curl_easy_get_response_body"]
opaque getResponseBody (h : @& Handle) : IO ByteArray

/-- The raw accumulated header block (status line, each `Key: Value` line, and the
blank separator lines), exactly as delivered by curl's `HEADERFUNCTION`. -/
@[extern "lean_curl_easy_get_response_headers_raw"]
opaque getResponseHeadersRaw (h : @& Handle) : IO String

/-- The message associated with a `CURLcode`, via `curl_easy_strerror`. -/
@[extern "lean_curl_strerror"]
opaque strerror (code : UInt32) : String

end Easy
end Leancurl
