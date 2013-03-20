default : test
.PHONY : build clean publish setup test

# Setup everything
setup :
	npm install

# Run test suite
test : setup clean
	npm test

# Remove temporary files
clean :
	rm -f lib/replay/*.js

# CoffeeScript to JavaScript
build : clean
	coffee -b -c -l -o lib/replay lib/replay/*.coffee

# Publish new release to NPM
publish : test
	npm publish
	git push



# Generate new SSL certificates
new-certificates : test/ssl/certificate.pem test/ssl/privatekey.pem
	rm -f request.pem

test/ssl/privatekey.pem :
	# Generate a Private Key
	openssl genrsa -out server.key 1024
	openssl rsa -in server.key -out test/ssl/privatekey.pem
	rm -f server.key

request.pem : test/ssl/privatekey.pem
	openssl req -new -key test/ssl/privatekey.pem -out request.pem

test/ssl/certificate.pem : request.pem test/ssl/privatekey.pem
	# Generating a Self-Signed Certificate
	openssl req -x509 -days 365 -key test/ssl/privatekey.pem -in request.pem -out test/ssl/certificate.pem
