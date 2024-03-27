#!/bin/bash

log() {
	echo "${0##*/}: $*" >&2
}

# Create the CA certificate
if ! [[ -f ca.crt ]]; then
	log "generating ca certificate"

	# we will need to regenerate localhost.crt if we are creating a new ca
	rm -f localhost.crt
	openssl req -x509 \
		-new -nodes \
		-newkey rsa:2048 -keyout ca.key \
		-sha256 -days 3650 -out ca.crt \
		-subj /CN='localhost ca'
fi

# Create certificate request for localhost
if ! [[ -f localhost.csr ]]; then
	log "generating localhost csr"
	openssl req \
		-newkey rsa:2048 -keyout localhost.key \
		-nodes -out localhost.csr \
		-subj /CN=localhost -addext subjectAltName=DNS:localhost
fi

# Sign the localhost certificate request
if ! [[ -f localhost.crt ]]; then
	log "signing localhost csr"
	openssl x509 -req -in localhost.csr -copy_extensions copy \
		-CA ca.crt -CAkey ca.key -CAcreateserial \
		-out localhost.crt -days 365 -sha256
fi

# Start webserver
log "starting webserver"
caddy run >/dev/null 2>&1 &
caddy_pid=$!

# Wait for caddy to start up
log "waiting for webserver to accept connections"
while ! curl -sf -o /dev/null http://localhost:8080; do
	sleep 1
done
echo

echo "=== should not validate ==="
curl https://localhost:8443

echo "=== should validate ==="
curl --cacert ca.crt https://localhost:8443
echo

# Stop webserver
log "stopping webserver"
kill $caddy_pid
