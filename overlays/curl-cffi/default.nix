# curl-cffi 0.15.0's test suite fails against the libcurl/http3 stack in the
# nixpkgs-unstable rev we track, which breaks yt-dlp (its only consumer here):
#
#   * the three `test_verify` cases assert on the literal string "SSL
#     certificate problem", but libcurl now reports an IP-address SAN mismatch
#     as "SSL: no alternative certificate subject name matches target ipv4
#     address '127.0.0.1'" — the connection is still correctly refused, only
#     the wording changed.
#   * `test_delete_cookies` expects an expiring Set-Cookie to drop the cookie
#     from the jar immediately; it stays for the session now.
#
# nixpkgs master already deselects exactly these four node IDs (pending the
# 0.16.0 bump); this is that patch backported until the branch catches up, so
# the resulting derivation matches upstream's and still substitutes from the
# binary cache. Drop this once nixpkgs-unstable has the fix.
_:

_final: prev:

{
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_pyFinal: pyPrev: {
      curl-cffi = pyPrev.curl-cffi.overridePythonAttrs (old: {
        disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
          "tests/unittest/test_async_session.py::test_verify"
          "tests/unittest/test_curl.py::test_verify"
          "tests/unittest/test_requests.py::test_verify"
          "tests/unittest/test_requests.py::test_delete_cookies"
        ];
      });
    })
  ];
}
