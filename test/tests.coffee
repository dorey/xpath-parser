should = require 'should'

log = (args...)->
  console.log("\n****\n")
  console.log.apply(console, args)
  console.log("\n****\n")

parse_expression = require '../lib/parse_expression'


describe 'should create equiv json', ->
  it 'simple lookup', ->
    parse_expression('${something}').decoded
                .should.deepEqual [
                    $lookup: "something"
                  ]

  it 'formbuilder typical sl', ->
    parse_expression("${a} = 'a' and ${b} = 'b' and ${c} = 'c'").decoded
                .should.deepEqual [
                  $lookup: 'a'
                  '='
                  "'a'"
                  'and'
                  $lookup: 'b'
                  '='
                  "'b'"
                  'and'
                  $lookup: 'c'
                  '='
                  "'c'"
                ]

  it 'simple xpaths', ->
    parse_expression('../doubledot/preceded/xpath').decoded
                .should.deepEqual [
                    "../doubledot/preceded/xpath"
                  ]

    parse_expression('/absolute/xpath').decoded
                  .should.deepEqual [
                    "/absolute/xpath"
                  ]

  it 'complex paths', ->
    parse_expression("instance('id')/path/to/node").decoded
                  .should.deepEqual [
                    "$fn": [
                      "instance"
                      "("
                      "'id'"
                      ")"
                    ]
                    "/path/to/node"
                  ]
    parse_expression("current()/path/to/node").decoded
                  .should.deepEqual [
                    "$fn": [
                      "current",
                      "(",
                      ")",
                    ]
                    "/path/to/node"
                  ]
  it 'parentheses', ->
    parse_expression('(asdf)').toObject()
                .should.deepEqual [["parens.OPEN", "asdf", "parens.CLOSED"]]

    parse_expression('(asdf)').decoded
                .should.deepEqual [
                    ["(", "asdf", ")"]
                  ]

  it 'punctuation', ->
    parse_expression('. > 3').toObject()
                .should.deepEqual [
                    "DOTSELF"
                    "comp.GT"
                    "3"
                  ]
    parse_expression('. > 3').decoded
                .should.deepEqual [
                    "."
                    ">"
                    "3"
                  ]

  it 'methods', ->
    parse_expression('count(asdf)').decoded
                .should.deepEqual [
                    "$fn": [
                      "count"
                      "("
                      "asdf"
                      ")"
                    ]
                  ]
  it 'conflicting method names', ->
    parse_expression('countries > 3').decoded
                .should.deepEqual [
                    "countries"
                    ">"
                    "3"
                  ]

  it 'complex methods', ->
    parse_expression('concat(count(current()/../path/node/*), ${a}, "2", "4")').decoded
                .should.deepEqual [
                  {
                    "$fn": [
                      "concat"
                      "("
                      {
                        "$fn": [
                          "count"
                          "("
                          {
                            "$fn": [
                              "current", "(", ")"
                            ]
                          }
                          "/../path/node/*"
                          ")"
                        ]
                      }
                      ","
                      {
                        "$lookup": "a"
                      }
                      ","
                      "'2'"
                      ","
                      "'4'"
                      ")"
                    ]
                  }
                ]


  describe 'strings', ->
    it 'single quotes', ->
      parse_expression("""
                  'abc'
                  """).decoded
                .should.deepEqual [
                    "'abc'"
                  ]

    it 'double quotes', ->
      parse_expression("""
                  "abc"
                  """).decoded
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
                  """).decoded
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

array_to_xpath = require('../lib/array_to_xpath').array_to_xpath

describe 'array to xpath', ->
  it 'converts array to string', ->
    array_to_xpath([]).should.equal('')

    array_to_xpath([
        'a',
        'b',
      ]).should.equal('ab')
  it 'parses objects', ->
    array_to_xpath([
        'a',
        something: 'b',
        'c',
      ]).should.equal('abc')

  it 'keys alphabetized, nested arrays', ->
    array_to_xpath([
        'a',
        something_b: 'b',
        something_c: 'c',
        'd',
        [
          [
            'e',
            'f',
            x: 'g',
          ]
        ],
      ]).should.equal('abcdefg')

  it 'commentable', ->
    array_to_xpath([
        'a',
        {
          '# pound sign starts a comment': 'never added',
        },
        'b',
      ]).should.equal('ab')

  it 'parens wrapped', ->
    array_to_xpath([
        'a',
        [
          '(',
          ')',
        ]
      ]).should.equal('a()')

  it 'spacing is good', ->
    array_to_xpath([
        'a',
        [
          '(',
          [
            '1'
            '2'
            '3'
          ]
          ')',
        ]
      # ]).should.equal('a(1. 2. 3)')
      ]).should.equal('a(123)')

  it 'arithmetic spacing', ->
    array_to_xpath([
      'a',
      [
        '(',
        [
          'x',
          '+',
          'y',
          ',',
          'z',
        ],
        ')',
      ],
      'b'
    ]).should.equal('a(x + y, z)b')

  it 'arithmetic spacing', ->
    array_to_xpath([
      'a',
      [
        '(',
        [
          'x',
          '+',
          'y',
          ',',
          'z',
        ],
        ')',
      ],
    ]).should.equal('a(x + y, z)')

  it 'default lookup function', ->
    array_to_xpath([
        $lookup: 'abc'
      ]).should.equal("${abc}")

  it 'custom lookup function', ->
    array_to_xpath([
        $lookup: 'abc'
      ], {
        $lookup: (s)-> "! #{s.toUpperCase()} ¡"
      }).should.equal("! ABC ¡")
  it 'other custom function', ->
    """
    just in case we want to start defining custom callbacks, starting
    with a "$"
    """
    array_to_xpath([
        $select1_question_not_equal: [
          "question_a",
          "'a'",
        ]
      ], {
        $select1_question_not_equal: (params)->
          "${#{params[0]}} != #{params[1]}"
        }).should.equal("${question_a} != 'a'")

  it 'and clause', ->
    array_to_xpath([
      {
        $and: [
          [
            $lookup: 'a',
            '=',
            "'a'",
          ]
          [
            $lookup: 'b',
            '=',
            "'b'",
          ]
          [
            $lookup: 'c',
            '=',
            "'c'",
          ]
        ],
      },
      ], {
      $and: (items)->
        for n in [items.length-1...0]
          items.splice(n, 0, 'and')
        items
    }).should.equal("${a} = 'a' and ${b} = 'b' and ${c} = 'c'")

  it 'real life example', ->
    expected = [
      "${question_a} != 'a'",
      "${question_b} <= 123",
      "not(selected(${question_c}, 'option_2'))",
      "${question_d} = 'option_2'",
    ].join(" and ")
    array_to_xpath([
        {
          # hypothetically, we might want to store them with a key: 'aa_q1'
          # object keys do not end up in the final output. Only object values
          'aa__q1': [
            $lookup: 'question_a',
            "!=",
            "'a'"
          ]
        },
        'and',
        [
          "${question_b}"
          "<="
          123
        ],
        'and'
        [
          {
            $multiselect_question_not_selected: [
              "question_c",
              "'option_2'",
            ]
          }
        ],
        'and',
        [
          # default behavior
          $lookup: 'question_d',
          "=",
          "'option_2'"
        ]
      ], {
        $multiselect_question_not_selected: ([qn, val])->
          [
            "not(selected(",
            $lookup: qn,
            ",",
            val
            "))",
          ]
      }).should.equal(expected)
    # array_to_xpath.log_ins_and_outs()

