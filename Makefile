PATH := ./node_modules/.bin:${PATH}

.PHONY : init build test dist publish

init:
	npm install

clean:
	rm -rf lib/ test/*.js

build:
	coffee -o lib/ -c src/ && coffee -c test/tests.coffee

test: build
	mocha test/tests.js

dist: clean init docs build test

publish: dist
	npm publish
