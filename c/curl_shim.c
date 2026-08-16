// Copyright (c) 2026 Paul Butcher. All rights reserved.
// Released under Apache 2.0 license as described in the file LICENSE.

#include <lean/lean.h>
#include <curl/curl.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

LEAN_EXPORT lean_object *lean_curl_version(lean_object *w) {
    return lean_io_result_mk_ok(lean_mk_string(curl_version()));
}

typedef struct {
    char *data;
    size_t len;
    size_t cap;
} lc_buffer;

typedef struct {
    CURL *curl;
    struct curl_slist *headerList;
    lc_buffer body;
    lc_buffer headers;
} lc_handle;

static void lc_buffer_append(lc_buffer *buf, const char *data, size_t n) {
    if (buf->len + n > buf->cap) {
        size_t newCap = buf->cap == 0 ? 4096 : buf->cap * 2;
        while (newCap < buf->len + n) newCap *= 2;
        buf->data = (char *)realloc(buf->data, newCap);
        buf->cap = newCap;
    }
    memcpy(buf->data + buf->len, data, n);
    buf->len += n;
}

static size_t lc_write_callback(char *ptr, size_t size, size_t nmemb, void *userdata) {
    lc_handle *h = (lc_handle *)userdata;
    size_t n = size * nmemb;
    lc_buffer_append(&h->body, ptr, n);
    return n;
}

static size_t lc_header_callback(char *ptr, size_t size, size_t nmemb, void *userdata) {
    lc_handle *h = (lc_handle *)userdata;
    size_t n = size * nmemb;
    lc_buffer_append(&h->headers, ptr, n);
    return n;
}

static void lc_handle_finalize(void *ptr) {
    lc_handle *h = (lc_handle *)ptr;
    curl_easy_cleanup(h->curl);
    curl_slist_free_all(h->headerList);
    free(h->body.data);
    free(h->headers.data);
    free(h);
}

// The handle owns no Lean objects, only C-managed buffers, so there is nothing to traverse.
static void lc_handle_foreach(void *mod, b_lean_obj_arg fn) {}

// `curl_global_cleanup` is deliberately not called: it would need to run after
// every other Lean finalizer at process exit, which Lean's module system has no
// hook for, and the OS reclaims the (purely in-process) resources it would free
// anyway.
static lean_external_class *g_handle_class = NULL;
static pthread_once_t g_init_once = PTHREAD_ONCE_INIT;

static void lc_init(void) {
    curl_global_init(CURL_GLOBAL_DEFAULT);
    g_handle_class = lean_register_external_class(lc_handle_finalize, lc_handle_foreach);
}

LEAN_EXPORT lean_object *lean_curl_easy_init(lean_object *w) {
    pthread_once(&g_init_once, lc_init);
    lc_handle *h = (lc_handle *)calloc(1, sizeof(lc_handle));
    h->curl = curl_easy_init();
    curl_easy_setopt(h->curl, CURLOPT_WRITEFUNCTION, lc_write_callback);
    curl_easy_setopt(h->curl, CURLOPT_WRITEDATA, h);
    curl_easy_setopt(h->curl, CURLOPT_HEADERFUNCTION, lc_header_callback);
    curl_easy_setopt(h->curl, CURLOPT_HEADERDATA, h);
    return lean_io_result_mk_ok(lean_alloc_external(g_handle_class, h));
}

static lc_handle *lc_get(b_lean_obj_arg handle) {
    return (lc_handle *)lean_get_external_data(handle);
}

LEAN_EXPORT lean_object *lean_curl_easy_set_url(b_lean_obj_arg handle, b_lean_obj_arg url, lean_object *w) {
    curl_easy_setopt(lc_get(handle)->curl, CURLOPT_URL, lean_string_cstr(url));
    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_object *lean_curl_easy_set_method(b_lean_obj_arg handle, b_lean_obj_arg method, lean_object *w) {
    curl_easy_setopt(lc_get(handle)->curl, CURLOPT_CUSTOMREQUEST, lean_string_cstr(method));
    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_object *lean_curl_easy_set_headers(b_lean_obj_arg handle, b_lean_obj_arg headers, lean_object *w) {
    lc_handle *h = lc_get(handle);
    struct curl_slist *list = NULL;
    size_t n = lean_array_size(headers);
    for (size_t i = 0; i < n; i++) {
        list = curl_slist_append(list, lean_string_cstr(lean_array_get_core(headers, i)));
    }
    curl_easy_setopt(h->curl, CURLOPT_HTTPHEADER, list);
    curl_slist_free_all(h->headerList);
    h->headerList = list;
    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_object *lean_curl_easy_set_post_fields(b_lean_obj_arg handle, b_lean_obj_arg body, lean_object *w) {
    CURL *curl = lc_get(handle)->curl;
    size_t n = lean_sarray_size(body);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (long)n);
    curl_easy_setopt(curl, CURLOPT_COPYPOSTFIELDS, (const char *)lean_sarray_cptr(body));
    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_object *lean_curl_easy_set_timeout_ms(b_lean_obj_arg handle, uint32_t ms, lean_object *w) {
    curl_easy_setopt(lc_get(handle)->curl, CURLOPT_TIMEOUT_MS, (long)ms);
    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_object *lean_curl_easy_set_follow_location(b_lean_obj_arg handle, uint8_t follow, lean_object *w) {
    curl_easy_setopt(lc_get(handle)->curl, CURLOPT_FOLLOWLOCATION, follow ? 1L : 0L);
    return lean_io_result_mk_ok(lean_box(0));
}

LEAN_EXPORT lean_object *lean_curl_easy_perform(b_lean_obj_arg handle, lean_object *w) {
    lc_handle *h = lc_get(handle);
    h->body.len = 0;
    h->headers.len = 0;
    CURLcode rc = curl_easy_perform(h->curl);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)rc));
}

LEAN_EXPORT lean_object *lean_curl_easy_get_response_code(b_lean_obj_arg handle, lean_object *w) {
    long code = 0;
    curl_easy_getinfo(lc_get(handle)->curl, CURLINFO_RESPONSE_CODE, &code);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)code));
}

LEAN_EXPORT lean_object *lean_curl_easy_get_response_body(b_lean_obj_arg handle, lean_object *w) {
    lc_handle *h = lc_get(handle);
    lean_object *arr = lean_alloc_sarray(1, h->body.len, h->body.len);
    if (h->body.len) memcpy(lean_sarray_cptr(arr), h->body.data, h->body.len);
    return lean_io_result_mk_ok(arr);
}

LEAN_EXPORT lean_object *lean_curl_easy_get_response_headers_raw(b_lean_obj_arg handle, lean_object *w) {
    lc_handle *h = lc_get(handle);
    return lean_io_result_mk_ok(lean_mk_string_from_bytes(h->headers.len ? h->headers.data : "", h->headers.len));
}

LEAN_EXPORT lean_object *lean_curl_strerror(uint32_t code) {
    return lean_mk_string(curl_easy_strerror((CURLcode)code));
}
