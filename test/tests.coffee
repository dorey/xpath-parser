should = require 'should'

log = (args...)-> console.log.apply(console, args)

parse_expression = require '../lib/parse_expression'

describe 'should create equiv json', ->
  it 'simple lookup', ->
    parse_expression('${something}').toObject()
                .should.deepEqual([{lookup: "something"}])

  it 'simple xpaths', ->
    parse_expression('../doubledot/preceded/xpath').toObject()
                .should.deepEqual [{path: "../doubledot/preceded/xpath"}]

    parse_expression('/absolute/xpath').toObject()
                .should.deepEqual [{path: "/absolute/xpath"}]

  it 'complex paths', ->
    parse_expression("instance('id')/path/to/node").toObject()
                .should.deepEqual [
                  {
                    path: [
                      {
                        method: 'instance', arguments: ["'id'"]
                      },
                      '/path/to/node'
                    ]
                  }
                ]
    parse_expression("current()/path/to/node").toObject()
                .should.deepEqual [
                  {
                    path: [
                      {
                        method: 'current', arguments: []
                      },
                      '/path/to/node'
                    ]
                  }
                ]

  it 'parentheses', ->
    parse_expression('(asdf)').toObject()
                .should.deepEqual [["asdf"]]

  it 'punctuation', ->
    parse_expression('. > 3').toObject()
                .should.deepEqual(
                      [
                        "DOTSELF"
                        "comp.GT"
                        "3"
                      ]
                  )

  it 'methods', ->
    parse_expression('count(asdf)').toObject()
                .should.deepEqual(
                      [{
                        method: "count",
                        arguments: ["asdf"]
                      }]
                  )

  it 'complex methods', ->
    parse_expression('concat(count(current()/../path/node/*), ${a}, "2", "4")').toObject()
                .should.deepEqual(
                    [{
                      "method": "concat",
                      "arguments": [
                        {
                          "method": "count",
                          "arguments": [{"path": [
                              {method: 'current', arguments: []},
                              "/../path/node/*"
                            ]}]
                        },
                        # including comma for now
                        "punc.COMMA",
                        {"lookup": "a"},
                        # including comma for now
                        "punc.COMMA",
                        "'2'",
                        # including comma for now
                        "punc.COMMA",
                        "'4'"
                      ]
                    }]
                  )


  describe 'strings', ->
    it 'single quotes', ->
      parse_expression("""
                  'abc'
                  """).toObject()
                .should.deepEqual(
                    ["'abc'"]
                  )

    it 'double quotes', ->
      parse_expression("""
                  "abc"
                  """).toObject()
                .should.deepEqual(
                  ["'abc'"]
                )

    it 'string containing "or" are ok', ->
      parse_expression("'my name is a or b'").toObject()
                .should.deepEqual(
                    ["'my name is a or b'"]
                  )

    it 'newlines', ->
      parse_expression("""
                  abc
                  def
                  """).toObject()
                .should.deepEqual(
                  ["abc", "spacing.NEWLINE", "def"]
                )

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
                        arguments: [],
                      },
                      '/path/to/node',
                    ]
                  }
                ]).toString()
                .should.equal('current()/path/to/node')
