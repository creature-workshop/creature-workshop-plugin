#!/bin/sh

:<<'MODULE'
HTTP request primitives with retry and status-code classification.

Behavior:
  2xx → succeed, echo response body
  4xx → fail immediately (client error, not retryable)
  5xx → retry with escalating timeouts
  curl error → warn and retry

All functions echo the response body on success and return 1 on failure.
MODULE

: <<'CONST'
Structs and the log verbs arrive from .envrc, which sources them before any
library; this file names no import so a test may source it on its own.
CONST
__http__DIR="$SHELLOPS_DIR/lib/http"

__http__RETRIES=3
__http__COOLDOWN_SECS=1
__http__TIMEOUT_STEP_SECS=2
__http__LAST_HTTP_CODE=""
__http__LAST_CURL_ERR=""
__http__LAST_BODY=""

__http__reset_failure_detail() {
  __http__LAST_HTTP_CODE=""
  __http__LAST_CURL_ERR=""
  __http__LAST_BODY=""
}

:<<'PUB_FUN'
Prints the response body of the last request that failed on a non-2xx status,
for a caller that reads the server's own error out of it. The request must
have run in the caller's shell: a request inside command substitution keeps
its failure detail in that subshell, so redirect its output to a file instead.

Usage:
  if ! http__post "$url" "$body" "$opts" > "$tmp"; then
    error "token request refused: $(@get "$(http__last_body)" '.error_description' '')"
  fi
PUB_FUN
http__last_body() {
  println "${__http__LAST_BODY:-}"
}

:<<'PUB_FUN'
Prints the status code of the last request that failed on a non-2xx status,
empty when curl got no status at all, for a caller deciding whether the
failure is worth another try. It lives in the caller's shell the way
http__last_body does, so the request must have run there.
PUB_FUN
http__last_status() {
  println "${__http__LAST_HTTP_CODE:-}"
}

__http__format_failure_detail() {
  __http__format_failure_detail__detail=""

  if [ -n "${__http__LAST_HTTP_CODE:-}" ]; then
    __http__format_failure_detail__detail="last status ${__http__LAST_HTTP_CODE}"
  fi

  if [ -n "${__http__LAST_CURL_ERR:-}" ]; then
    if [ -n "$__http__format_failure_detail__detail" ]; then
      __http__format_failure_detail__detail="${__http__format_failure_detail__detail}; curl: ${__http__LAST_CURL_ERR}"
    else
      __http__format_failure_detail__detail="curl: ${__http__LAST_CURL_ERR}"
    fi
  fi

  if [ -n "$__http__format_failure_detail__detail" ]; then
    printf ' (%s)' "$__http__format_failure_detail__detail"
  fi
}

:<<'PUB_FUN'
Prints query $1, an object of parameters, as the query string a URL
carries: every value percent-encoded, the pairs joined with &.

  http__query_string "$(@obj '.q' "name = 'a'" '.fields' 'id,name')"
    -> q=name%20%3D%20%27a%27&fields=id%2Cname
PUB_FUN
http__query_string() {
  @run_awk __http__query_string__out "$__http__DIR/query_string.awk" "$1" --load "$__http__DIR/uri.awk" || return 1
  println "$__http__query_string__out"
}

:<<'PUB_FUN'
Prints string $1 percent-encoded as one URL component, fit to stand as a
path segment or a parameter value.

  http__encode "'Over cap'!A1:Y"  ->  %27Over%20cap%27%21A1%3AY
PUB_FUN
http__encode() {
  case "$1" in
    # structs-lint: allow -- the bytes a URL component holds as they are (RFC 3986), in plain text
    *[!A-Za-z0-9._~-]*) __http__encode_bytes "$1" ;;
    *) println "$1" ;;
  esac
}

:<<'FUN'
Prints string $1 with every byte outside the unreserved set of RFC 3986 as
%XX, through uri.awk and encode.awk beside this file.

  __http__encode_bytes 'a b'  ->  a%20b
FUN
__http__encode_bytes() {
  println "$1" \
    | LC_ALL=C awk \
      -f "$__http__DIR/uri.awk" \
      -f "$__http__DIR/encode.awk"
}

:<<'PUB_FUN'
Prints string $1 with its percent-escapes decoded, the inverse of the
encoding http__query_string and http__encode apply. A reader of a recorded
URL uses it to compare the parameters a request meant.

  http__query_decode 'q=name%20%3D%20%27a%27'  ->  q=name = 'a'
PUB_FUN
http__query_decode() {
  println "$1" | awk -f "$__http__DIR/query_decode.awk"
}

:<<'PUB_FUN'
Convenience wrapper for GET requests.

Usage:
  http__get "$url"
  http__get "$url" '{"auth":"Bearer x"}'
PUB_FUN
http__get() {
  __http__get__options="${2:-}"
  [ -n "$__http__get__options" ] || @obj __http__get__options
  http__request "GET" "$1" "" "$__http__get__options"
}

:<<'PUB_FUN'
Convenience wrapper for POST requests. Sets Content-Type to
application/json unless options.content_type overrides it.

Usage:
  http__post "$url" "$json_body"
  http__post "$url" "$json_body" '{"auth":"Bearer x"}'
PUB_FUN
http__post() {
  __http__post__body="${2:-}"
  __http__post__options="${3:-}"
  [ -n "$__http__post__options" ] || @obj __http__post__options

  @get __http__post__content_type "$__http__post__options" '.content_type' 'application/json'
  @set __http__post__options "$__http__post__options" '.content_type' "$__http__post__content_type"

  http__request "POST" "$1" "$__http__post__body" "$__http__post__options"
}

:<<'PUB_FUN'
Convenience wrapper for PUT requests. Sets Content-Type to
application/json unless options.content_type overrides it.

Usage:
  http__put "$url" "$json_body" '{"auth":"Bearer x"}'
PUB_FUN
http__put() {
  __http__put__body="${2:-}"
  __http__put__options="${3:-}"
  [ -n "$__http__put__options" ] || @obj __http__put__options

  @get __http__put__content_type "$__http__put__options" '.content_type' 'application/json'
  @set __http__put__options "$__http__put__options" '.content_type' "$__http__put__content_type"

  http__request "PUT" "$1" "$__http__put__body" "$__http__put__options"
}

:<<'PUB_FUN'
Convenience wrapper for PATCH requests. Sets Content-Type to
application/json unless options.content_type overrides it.

Usage:
  http__patch "$url" "$json_body" '{"auth":"token x"}'
PUB_FUN
http__patch() {
  __http__patch__body="${2:-}"
  __http__patch__options="${3:-}"
  [ -n "$__http__patch__options" ] || @obj __http__patch__options

  @get __http__patch__content_type "$__http__patch__options" '.content_type' 'application/json'
  @set __http__patch__options "$__http__patch__options" '.content_type' "$__http__patch__content_type"

  http__request "PATCH" "$1" "$__http__patch__body" "$__http__patch__options"
}

:<<'PUB_FUN'
Convenience wrapper for DELETE requests.

Usage:
  http__delete "$url" '{"auth":"Bearer x"}'
PUB_FUN
http__delete() {
  __http__delete__options="${2:-}"
  [ -n "$__http__delete__options" ] || @obj __http__delete__options
  http__request "DELETE" "$1" "" "$__http__delete__options"
}

:<<'PUB_FUN'
Uploads a file, via POST unless options.method names another verb. Supports
two modes via options.upload_mode:

  "form"   (default) — multipart form upload (-F). Field name controlled
           by options.form_field (default "file").
  "binary" — raw body upload (--data-binary). Content-Type set from
           options.content_type (default "application/octet-stream").

Usage:
  http__upload "$url" "$filepath" '{"auth":"Bearer x","upload_mode":"binary"}'
  http__upload "$url" "$filepath" '{"auth":"token x","form_field":"attachment"}'
PUB_FUN
http__upload() {
  __http__upload__url="$1"
  __http__upload__filepath="$2"
  __http__upload__options="${3:-}"
  [ -n "$__http__upload__options" ] || @obj __http__upload__options

  __http__reset_failure_detail

  @let "$__http__upload__options" __http__upload__ auth accept upload_mode method content_type form_field
  @defined "$__http__upload__accept" || __http__upload__accept='application/json'
  @defined "$__http__upload__upload_mode" || __http__upload__upload_mode='form'
  @defined "$__http__upload__method" || __http__upload__method='POST'

  # The curl argv is built in the positional parameters (POSIX sh has no
  # arrays): reset them with set -- and append per option.
  set -- -sS -w '\n%{http_code}' -X "$__http__upload__method" -H "Accept: $__http__upload__accept"

  if @defined "$__http__upload__auth"; then
    set -- "$@" -H "Authorization: $__http__upload__auth"
  fi

  case "$__http__upload__upload_mode" in
    binary)
      @defined "$__http__upload__content_type" || __http__upload__content_type='application/octet-stream'
      set -- "$@" -H "Content-Type: $__http__upload__content_type" --data-binary "@$__http__upload__filepath"
      ;;
    form)
      @defined "$__http__upload__form_field" || __http__upload__form_field='file'
      set -- "$@" -F "${__http__upload__form_field}=@${__http__upload__filepath}"
      ;;
    *)
      error "http__upload: unknown upload_mode '$__http__upload__upload_mode'"
      return 1
      ;;
  esac

  if ! __http__with_retry "$__http__upload__options" __http__request_attempt "$__http__upload__method" "$__http__upload__url" "$@"; then
    error "HTTP $__http__upload__method $__http__upload__url failed after retries$(__http__format_failure_detail)"
    return 1
  fi
  @unlet __http__upload__ auth accept upload_mode method content_type form_field
}

# CONST: The hosts GitHub serves downloads from, which the download mirror stands in for.
__http__GITHUB_DOWNLOAD_HOSTS="github.com objects.githubusercontent.com raw.githubusercontent.com"

:<<'PUB_FUN'
Prints the URL a download of <url> really fetches. When OPS_DOWNLOAD_MIRROR
names a base URL, a download from one of GitHub's hosts goes to the mirror
instead. The mirror's root stands for github.com, so a github.com path is
kept as it is; raw.githubusercontent.com and objects.githubusercontent.com
sit under a path named after the host. Every other URL, and every URL
while the variable is unset, is printed unchanged. http__download applies
this to every download, so a recipe composes the upstream URL and never
reads the variable itself.

  OPS_DOWNLOAD_MIRROR=http://cache.ci.svc http__download_url https://github.com/o/r/releases/download/v1/a.tgz
    ->  http://cache.ci.svc/o/r/releases/download/v1/a.tgz
  OPS_DOWNLOAD_MIRROR=http://cache.ci.svc http__download_url https://raw.githubusercontent.com/o/r/main/f.sh
    ->  http://cache.ci.svc/raw.githubusercontent.com/o/r/main/f.sh
  http__download_url https://go.dev/dl/go1.25.tar.gz  ->  https://go.dev/dl/go1.25.tar.gz
PUB_FUN
http__download_url() {
  __http__download_url__mirror="${OPS_DOWNLOAD_MIRROR:-}"
  __http__download_url__path="$(__http__mirror_path "$1")"

  if @defined "$__http__download_url__mirror" && @defined "$__http__download_url__path"; then
    println "${__http__download_url__mirror%/}/$__http__download_url__path"
  else
    println "$1"
  fi
}

:<<'PUB_FUN'
Prints the Authorization value a download of <url> carries when the caller
names none: GitHub's token scheme with GITHUB_TOKEN for a download from
github.com while that variable is set, and nothing otherwise. GitHub
throttles anonymous downloads and spares authenticated ones. A download the
mirror serves is not on github.com, so it carries no token.

  GITHUB_TOKEN=t http__download_auth https://github.com/o/r/releases/download/v1/a.tgz  ->  token t
  GITHUB_TOKEN=t http__download_auth https://go.dev/dl/go1.25.tar.gz                   ->  (nothing)
PUB_FUN
http__download_auth() {
  if @is_true "$(__http__on_github "$1")" && @defined "${GITHUB_TOKEN:-}"; then
    println "token $GITHUB_TOKEN"
  fi
}

: <<'FUN'
Prints the path the mirror serves <url> under: the URL's own path for
github.com, the host and then the path for GitHub's other download hosts,
and nothing for a URL on any other host.

  __http__mirror_path https://github.com/o/r/releases/download/v1/a.tgz  ->  o/r/releases/download/v1/a.tgz
  __http__mirror_path https://raw.githubusercontent.com/o/r/main/f.sh    ->  raw.githubusercontent.com/o/r/main/f.sh
  __http__mirror_path https://go.dev/dl/go1.25.tar.gz                   ->  (nothing)
FUN
__http__mirror_path() {
  if @is_true "$(__http__on_github "$1")"; then
    println "${1#https://github.com/}"
    return 0
  fi

  for __http__mirror_path__host in $__http__GITHUB_DOWNLOAD_HOSTS; do
    if [ "${1#"https://$__http__mirror_path__host/"}" != "$1" ]; then
      println "${1#https://}"
      return 0
    fi
  done
}

: <<'FUN'
Prints true when <url> is on github.com itself, false otherwise.
FUN
__http__on_github() {
  if [ "${1#https://github.com/}" != "$1" ]; then
    println true
  else
    println false
  fi
}

:<<'PUB_FUN'
Downloads a file from a URL to a local path with retry on failure.

Unlike http__get, this writes directly to disk via curl -o, making it
safe for binary content (tarballs, images, etc.).

The URL fetched is the one http__download_url prints for <url>, so a
download from GitHub goes through the mirror OPS_DOWNLOAD_MIRROR names when
it is set. With no auth option, the request carries what http__download_auth
prints for that URL: GITHUB_TOKEN for a download from github.com.

Parameters:
  url       Full download URL
  dest      Local file path to write to
  options   Optional JSON object with any of:
              auth     - Authorization header value
              retries  - Number of attempts. Defaults to 3.
              max_time - Fixed curl --max-time in seconds.

Usage:
  http__download "$url" "/tmp/archive.tar.xz"
  http__download "$url" "$dest" '{"retries":5}'
PUB_FUN
http__download() {
  __http__download__url="$(http__download_url "$1")"
  __http__download__dest="$2"
  __http__download__options="${3:-}"
  [ -n "$__http__download__options" ] || @obj __http__download__options

  if [ "$__http__download__url" != "$1" ]; then
    log "downloading $1 through the mirror OPS_DOWNLOAD_MIRROR names: $__http__download__url"
  fi

  @get __http__download__auth "$__http__download__options" '.auth' ''
  if ! @defined "$__http__download__auth"; then
    __http__download__auth="$(http__download_auth "$__http__download__url")"
  fi

  set -- -fSL -o "$__http__download__dest"

  if @defined "$__http__download__auth"; then
    set -- "$@" -H "Authorization: $__http__download__auth"
  fi

  if ! __http__with_retry "$__http__download__options" __http__download_attempt "$__http__download__url" "$@"; then
    rm -f "$__http__download__dest"
    error "download failed: $__http__download__url"
    return 1
  fi
}

__http__download_attempt() {
  __http__download_attempt__attempt="$1"
  __http__download_attempt__retries="$2"
  __http__download_attempt__timeout="$3"
  __http__download_attempt__max_time="$4"
  __http__download_attempt__url="$5"
  shift 5

  __http__download_attempt__curl_err="$(mktemp)"

  if curl "$@" --connect-timeout "$__http__download_attempt__timeout" --max-time "$__http__download_attempt__max_time" "$__http__download_attempt__url" 2>"$__http__download_attempt__curl_err"; then
    rm -f "$__http__download_attempt__curl_err"
    return 0
  fi

  if [ -s "$__http__download_attempt__curl_err" ]; then
    warn "Attempt $__http__download_attempt__attempt/$__http__download_attempt__retries: $(cat "$__http__download_attempt__curl_err")"
  fi
  rm -f "$__http__download_attempt__curl_err"
  return 1
}

:<<'FUN'
Prints the request body <body> as it goes on the wire: a struct as JSON,
whatever form the structs backend holds it in, since JSON is what a server
reads; any other text as written.

  __http__body_on_the_wire "$(@obj .a 1)"  ->  {"a": 1}, over lines
  __http__body_on_the_wire 'grant_type=x'  ->  grant_type=x
FUN
__http__body_on_the_wire() {
  if @dump __http__body_on_the_wire__json "$1" 2>/dev/null; then
    println "$__http__body_on_the_wire__json"
  else
    println "$1"
  fi
}

:<<'PUB_FUN'
Low-level HTTP request with automatic retry on server errors.

Prefer the method wrappers (http__get, http__post, http__patch, http__delete)
for standard usage. Call http__request directly only for methods that lack
a wrapper (PUT, etc.).

Parameters:
  method   HTTP method (GET, POST, PATCH, DELETE, etc.)
  url      Full request URL
  body     Optional. Request body.
  options  Optional JSON object with any of:
             auth         - Authorization header value (e.g. "token abc", "Bearer abc")
             accept       - Accept header value. Defaults to "application/json".
             content_type - Content-Type header value. Set by http__post/http__patch; omitted if absent.
             headers      - Object of further headers, name to value, for an API
                            that carries its key or its version outside
                            Authorization (e.g. {"x-api-key":"k"}).
             max_time     - Fixed curl --max-time in seconds. Overrides escalating default.
             retries      - Number of attempts. Defaults to 3.
PUB_FUN
http__request() {
  __http__request__method="$1"
  __http__request__url="$2"
  __http__request__body="${3:-}"
  __http__request__options="${4:-}"
  [ -n "$__http__request__options" ] || @obj __http__request__options

  __http__reset_failure_detail

  @let "$__http__request__options" __http__request__ auth accept content_type
  @defined "$__http__request__accept" || __http__request__accept='application/json'

  set -- -sS -w '\n%{http_code}' -X "$__http__request__method" -H "Accept: $__http__request__accept"

  if @defined "$__http__request__auth"; then
    set -- "$@" -H "Authorization: $__http__request__auth"
  fi

  if @defined "$__http__request__content_type"; then
    set -- "$@" -H "Content-Type: $__http__request__content_type"
  fi

  if [ -n "$__http__request__body" ]; then
    __http__request__body="$(__http__body_on_the_wire "$__http__request__body")"
    set -- "$@" --data "$__http__request__body"
  fi

  @apply __http__send \
    "$__http__request__options" \
    "$__http__request__method" \
    "$__http__request__url" \
    "$@" \
    "$(__http__header_flags "$__http__request__options")" \
    || return 1
  @unlet __http__request__ auth accept content_type
}

:<<'FUN'
Prints the curl arguments the request options $1's further headers take, as an
array; empty when the options name none.

  __http__header_flags '{"headers":{"x-api-key":"k"}}'  ->  ["-H","x-api-key: k"]
FUN
__http__header_flags() {
  @run_awk __http__header_flags__out "$__http__DIR/header_flags.awk" "$1" || return 1
  println "$__http__header_flags__out"
}

:<<'FUN'
Runs one request and reports the failure the way every caller of http__request
reads it: the options $1 say how often to retry, $2 and $3 are the method and
the URL, and $4... are curl's own arguments. Runs in the caller's shell, so
what http__last_body and http__last_status print outlives the call.
FUN
__http__send() {
  __http__send__options="$1"
  __http__send__method="$2"
  __http__send__url="$3"
  shift 3

  if ! __http__with_retry "$__http__send__options" __http__request_attempt "$__http__send__method" "$__http__send__url" "$@"; then
    error "HTTP $__http__send__method $__http__send__url failed after retries$(__http__format_failure_detail)"
    return 1
  fi
}

:<<'FUN'
Prints the status code on the last line of curl's output $1, the line -w
'\n%{http_code}' appends; empty when curl got no answer, which it writes
as 000 and this treats as no status, so a connection failure is retried
and reported as curl's own reason rather than as a status.
FUN
__http__status_of() {
  __http__status_of__code="$(println "$1" | tail -n1)"
  case "$__http__status_of__code" in
    000) printf '\n' ;;
    *) printf '%s\n' "$__http__status_of__code" ;;
  esac
}

__http__request_attempt() {
  __http__request_attempt__attempt="$1"
  __http__request_attempt__retries="$2"
  __http__request_attempt__timeout="$3"
  __http__request_attempt__max_time="$4"
  __http__request_attempt__method="$5"
  __http__request_attempt__url="$6"
  shift 6

  __http__request_attempt__curl_err="$(mktemp)"

  __http__request_attempt__raw="$(curl "$@" --connect-timeout "$__http__request_attempt__timeout" --max-time "$__http__request_attempt__max_time" "$__http__request_attempt__url" 2>"$__http__request_attempt__curl_err")" || true
  __http__request_attempt__http_code="$(__http__status_of "$__http__request_attempt__raw")"
  __http__request_attempt__result="$(println "$__http__request_attempt__raw" | sed '$d')"

  case "$__http__request_attempt__http_code" in
    2*)
      rm -f "$__http__request_attempt__curl_err"
      echo "$__http__request_attempt__result"
      return 0
      ;;
  esac

  __http__LAST_HTTP_CODE="${__http__request_attempt__http_code:-}"
  __http__LAST_BODY="$__http__request_attempt__result"

  if [ -s "$__http__request_attempt__curl_err" ]; then
    __http__LAST_CURL_ERR="$(cat "$__http__request_attempt__curl_err")"
    warn "Attempt $__http__request_attempt__attempt/$__http__request_attempt__retries: ${__http__LAST_CURL_ERR}"
  fi
  rm -f "$__http__request_attempt__curl_err"

  case "$__http__request_attempt__http_code" in
    5*|"") return 1 ;;
    *) return 2 ;;
  esac
}

: <<'FUN'
Retry loop with escalating timeouts. Delegates each attempt to a callback.

Callback signature:
  callback "$attempt" "$retries" "$timeout" "$max_time" [extra_args...]

Callback return codes:
  0 — success, stop retrying
  1 — retryable failure, try again (e.g. 5xx, network error)
  2 — non-retryable failure, bail immediately (e.g. 4xx)
FUN
__http__with_retry() {
  __http__with_retry__options="$1"
  __http__with_retry__callback="$2"
  shift 2

  @let "$__http__with_retry__options" __http__with_retry__ retries max_time
  @defined "$__http__with_retry__retries" || __http__with_retry__retries="$__http__RETRIES"
  __http__with_retry__max_time_override="$__http__with_retry__max_time"

  __http__with_retry__attempt=1
  while [ "$__http__with_retry__attempt" -le "$__http__with_retry__retries" ]; do
    [ "$__http__with_retry__attempt" -gt 1 ] && sleep "$__http__COOLDOWN_SECS"

    __http__with_retry__timeout=$(( __http__TIMEOUT_STEP_SECS * __http__with_retry__attempt ))
    if @defined "$__http__with_retry__max_time_override"; then
      __http__with_retry__max_time="$__http__with_retry__max_time_override"
    else
      __http__with_retry__max_time=$(( __http__with_retry__timeout * 4 ))
    fi

    __http__with_retry__rc=0
    "$__http__with_retry__callback" \
      "$__http__with_retry__attempt" \
      "$__http__with_retry__retries" \
      "$__http__with_retry__timeout" \
      "$__http__with_retry__max_time" \
      "$@" || __http__with_retry__rc=$?

    case $__http__with_retry__rc in
      0) return 0 ;;
      2) return 1 ;;
      *) ;;
    esac

    __http__with_retry__attempt=$(( __http__with_retry__attempt + 1 ))
  done

  @unlet __http__with_retry__ retries max_time
  return 1
}
