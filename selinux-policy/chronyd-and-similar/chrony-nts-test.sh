#!/bin/bash

set -e

server_name=chrony-nts-test
cert=/etc/pki/tls/certs/nts.crt
key=/etc/pki/tls/private/nts.key

sed -i "/ $server_name\$/d" /etc/hosts
echo "127.0.0.1 $server_name" >> /etc/hosts

cat > cert.cfg <<EOF
cn = "$server_name"
serial = 001
activation_date = "2020-01-01 00:00:00 UTC"
expiration_date = "2030-01-01 00:00:00 UTC"
signing_key
encryption_key
EOF

certtool --generate-privkey --key-type=ed25519 --outfile $key
certtool --generate-self-signed --load-privkey $key --template cert.cfg --outfile $cert
chmod 640 $cert $key
chown root:chrony $cert $key

cat > /etc/chrony.conf <<EOF
server chrony-nts-test iburst nts
server time.cloudflare.com iburst nts
ntsserverkey $key
ntsservercert $cert
ntstrustedcerts $cert
ntsdumpdir /var/lib/chrony
local
allow
EOF

systemctl restart chronyd

sleep 3

chronyc -N authdata