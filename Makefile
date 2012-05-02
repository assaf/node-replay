default : test
.PHONY : clean setup test

# Setup everything
setup :
	npm install

# Run test suite
test : setup clean
	npm test

# Remove temporary files
clean :
	rm -f lib/*.js
	rm -f lib/replay/*.js

# CoffeeScript to JavaScript
build : clean
	coffee -b -c -l -o lib/replay lib/replay/*.coffee

# Publish new release to NPM
publish : test
	npm publish
	git push
