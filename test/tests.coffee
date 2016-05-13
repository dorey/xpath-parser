should = require 'should'

log = (args...)->
  console.log("\n****\n")
  console.log.apply(console, args)
  console.log("\n****\n")

parse_expression = require '../lib/parse_expression'

describe 'should create equiv json', ->
  it 'simple lookup', ->
    parse_expression('${something}').toFlatDumbObject()
                .should.deepEqual [
                    lookup: "something"
                  ]

  it 'simple xpaths', ->
    parse_expression('../doubledot/preceded/xpath').toFlatDumbObject()
                .should.deepEqual [
                    "../doubledot/preceded/xpath"
                  ]

    parse_expression('/absolute/xpath').toFlatDumbObject()
                  .should.deepEqual [
                    "/absolute/xpath"
                  ]

  it 'complex paths', ->
    parse_expression("instance('id')/path/to/node").toFlatDumbObject()
                  .should.deepEqual [
                    "instance"
                    "("
                    "'id'"
                    ")"
                    "/path/to/node"
                  ]
    parse_expression("current()/path/to/node").toFlatDumbObject()
                  .should.deepEqual [
                    "current",
                    "(",
                    ")",
                    "/path/to/node"
                  ]

  it 'parentheses', ->
    parse_expression('(asdf)').toObject()
                .should.deepEqual [["parens.OPEN", "asdf", "parens.CLOSED"]]

    parse_expression('(asdf)').toFlatDumbObject()
                .should.deepEqual ["(", "asdf", ")"]

  it 'punctuation', ->
    parse_expression('. > 3').toObject()
                .should.deepEqual [
                    "DOTSELF"
                    "comp.GT"
                    "3"
                  ]
    parse_expression('. > 3').toFlatDumbObject()
                .should.deepEqual [
                    "."
                    ">"
                    "3"
                  ]

  it 'methods', ->
    parse_expression('count(asdf)').toFlatDumbObject()
                .should.deepEqual [
                    "count"
                    "("
                    "asdf"
                    ")"
                  ]

  it 'conflicting method names', ->
    parse_expression('countries > 3').toFlatDumbObject()
                .should.deepEqual [
                    "countries"
                    ">"
                    "3"
                  ]

  it 'complex methods', ->
    parse_expression('concat(count(current()/../path/node/*), ${a}, "2", "4")').toFlatDumbObject()
                .should.deepEqual [
                  "concat"
                  "("
                  "count"
                  "("
                  "current"
                  "("
                  ")"
                  "/../path/node/*"
                  ")"
                  ","
                  lookup: "a"
                  ","
                  "'2'"
                  ","
                  "'4'"
                  ")"
                ]


  describe 'strings', ->
    it 'single quotes', ->
      parse_expression("""
                  'abc'
                  """).toFlatDumbObject()
                .should.deepEqual [
                    "'abc'"
                  ]

    it 'double quotes', ->
      parse_expression("""
                  "abc"
                  """).toFlatDumbObject()
                .should.deepEqual [
                    "'abc'"
                  ]
  
    it 'string containing "or" are ok', ->
      parse_expression("'my name is a or b'").toObject()
                .should.deepEqual [
                    "'my name is a or b'"
                  ]

    it 'newlines', ->
      parse_expression("""
                  abc
                  def
                  """).toFlatDumbObject()
                .should.deepEqual [
                    "abc"
                    "\n"
                    "def"
                  ]

describe 'accepts array input', ->
  it 'simple array', ->
    parse_expression(['abc', '>', 'xyz']).toString()
                .should.equal('abc > xyz')
    parse_expression(['abc', 'comp.GT', 'xyz']).toString()
                .should.equal('abc > xyz')

  it 'complex paths', ->
    parse_expression([
                  {
                    path: [
                      {
                        method: 'current',
                        arguments: ["parens.OPEN", "parens.CLOSED"],
                      },
                      '/path/to/node',
                    ]
                  }
                ]).toString()
                .should.equal('current()/path/to/node')
