verify:
	openssl verify -verbose -CRLfile static/tls-ca.crl -extended_crl -crl_check -show_chain -CAfile static/root-ca.crt -untrusted static/tls-ca.crt static/schlac.test.crt

revoke:
	openssl ca -config etc/tls-ca.conf -revoke static/schlac.test.crt -crl_reason affiliationChanged
	openssl ca -gencrl -config etc/tls-ca.conf -out crl/tls-ca.crl

serve:
	mkdir -p static
	find . \( -name *.crt -o -name *.cer -o -name *.crl \) -exec sh -c 'echo {}; cp {} ./static/' \;
	
	-podman stop cert-nginx
	podman run --rm --name cert-nginx -d -p 8080:80 -v "./static:/usr/share/nginx/html:Z" nginx

generate: clean
	mkdir -p ca/root-ca/private ca/root-ca/db crl certs
	chmod 700 ca/root-ca/private
	touch ca/root-ca/db/root-ca.db ca/root-ca/db/root-ca.db.attr
	echo 01 > ca/root-ca/db/root-ca.crt.srl
	echo 01 > ca/root-ca/db/root-ca.crl.srl
	openssl req -new -config etc/root-ca.conf -out ca/root-ca.csr -keyout ca/root-ca/private/root-ca.key -nodes
	openssl ca -selfsign -config etc/root-ca.conf -in ca/root-ca.csr -out ca/root-ca.crt -extensions root_ca_ext -enddate 20231231235959Z
	openssl ca -gencrl -config etc/root-ca.conf -out crl/root-ca.crl
	openssl x509 -in ca/root-ca.crt -out ca/root-ca.cer -outform der
	
	mkdir -p ca/tls-ca/private ca/tls-ca/db crl certs
	chmod 700 ca/tls-ca/private
	touch ca/tls-ca/db/tls-ca.db ca/tls-ca/db/tls-ca.db.attr
	echo 01 > ca/tls-ca/db/tls-ca.crt.srl
	echo 01 > ca/tls-ca/db/tls-ca.crl.srl
	openssl req -new -config etc/tls-ca.conf -out ca/tls-ca.csr -keyout ca/tls-ca/private/tls-ca.key -nodes
	openssl ca -config etc/root-ca.conf -in ca/tls-ca.csr -out ca/tls-ca.crt -extensions signing_ca_ext
	openssl ca -gencrl -config etc/tls-ca.conf -out crl/tls-ca.crl
	cat ca/tls-ca.crt ca/root-ca.crt > ca/tls-ca-chain.pem
	openssl x509 -in ca/tls-ca.crt -out ca/tls-ca.cer -outform der
	
	SAN=DNS:schlac.test openssl req -new -config etc/server.conf -out certs/schlac.test.csr -keyout certs/schlac.test.key
	openssl ca -config etc/tls-ca.conf -in certs/schlac.test.csr -out certs/schlac.test.crt -extensions server_ext
	openssl x509 -in ca/tls-ca.crt -out ca/tls-ca.cer -outform der

clean:
	-podman stop cert-nginx
	-rm -r ca
	-rm -r crl
	-rm -r certs
	-rm -r static

