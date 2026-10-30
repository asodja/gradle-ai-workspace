# Sourced by every bash in the sandbox (BASH_ENV and /etc/bash.bashrc).
#
# OpenShell terminates TLS for inspected hosts with a per-sandbox CA and
# publishes it through SSL_CERT_FILE, CURL_CA_BUNDLE, and GIT_SSL_CAINFO.
# The JVM ignores those variables, so Gradle and Maven fail with PKIX errors
# unless the CA is in a Java truststore. The CA changes on every sandbox
# generation, so the truststore is rebuilt when the CA changes.
#
# The JVM also connects to IPv4-mapped IPv6 addresses by default, which the
# OpenShell proxy cannot match to a hostname; preferIPv4Stack avoids that.

openshell_java_trust() {
  ca=/run/openshell-supervisor-ca/material/ca.crt
  [ -r "$ca" ] || return 0
  case "${JAVA_TOOL_OPTIONS:-}" in *openshell-java/cacerts*) return 0 ;; esac

  dir="${XDG_CACHE_HOME:-$HOME/.cache}/openshell-java"
  store="$dir/cacerts"
  sum="$(sha256sum "$ca" | cut -c1-64)"
  if [ ! -f "$store" ] || [ "$(cat "$dir/ca.sha256" 2>/dev/null)" != "$sum" ]; then
    mkdir -p "$dir"
    tmp="$(mktemp "$dir/cacerts.XXXXXX")"
    cp /etc/ssl/certs/java/cacerts "$tmp"
    JAVA_TOOL_OPTIONS= keytool -importcert -noprompt -keystore "$tmp" -storepass changeit \
      -alias openshell-sandbox-ca -file "$ca" >/dev/null 2>&1 \
      && mv "$tmp" "$store" && printf '%s\n' "$sum" > "$dir/ca.sha256"
    rm -f "$tmp"
  fi
  [ -f "$store" ] || return 0

  export JAVA_TOOL_OPTIONS="-Djava.net.preferIPv4Stack=true -Djavax.net.ssl.trustStore=$store -Djavax.net.ssl.trustStorePassword=changeit${JAVA_TOOL_OPTIONS:+ $JAVA_TOOL_OPTIONS}"
}
openshell_java_trust
unset -f openshell_java_trust
