PATH := ./node_modules/.bin:${PATH}

.PHONY : init build test dist publish

init:
	npm install

clean:
	rm -rf lib/ test/*.js

build:
	coffee -o lib/ -c src/

test: build
	mocha

dist: clean init build test

publish: dist
	npm publish
