_ = require('underscore')

params =
  "categories": [
      'punctuation'
      'prefix'
      'methods'
      'spacing'
      'unkown'
      'parentheses'
      'comparators'
      'operators'
      'values'
      'logic'
    ],
  "prefix": {
    matchers: [
      {
        regex: '^jr\:',
        string: 'jr:',
        repr: 'JR',
      }
    ]
  }
  "punctuation": {
    abbr: "punc"
    matchers: [
      ["..", "DOTPREVIOUS"],
      [".", "DOTSELF"],
      ["//", 'DBLFWDSLASH']
      ["/", 'FWDSLASH']
      [",", 'COMMA']
    ]
  },
  "methods": {
    abbr: "method",
    matchers: [
      "ceiling"
      "concat"
      "count"
      "count-selected"
      "current"
      "date"
      "false"
      "floor"
      "id"
      "if"
      "not"
      "position"
      "regex"
      "round"
      "selected"
      "selected-at"
      "string"
      "string-length"
      "substr"
      "sum"
      "today"
      "true"
    ]
  },
  "spacing": {
    matchers: [
      ["\n", "NEWLINE"]
    ]
  },
  "unkown": {
    "abbr": "unk",
    matchers: [
      "undefined"
    ]
  }
  "comparators": {
    abbr: "comp",
    matchers: [
      [">=", "GTE"]
      ["<=", "LTE"]
      ["!=", "NEQ"]
      ["=", "EQ"]
      [">", "GT"]
      ["<", "LT"]
    ]
  },
  "operators": {
    abbr: "op"
    matchers: [
      ["+", 'PLUS']
      ["-", 'MINUS']
      ["*", "MULT"]
      "div"
      "mod"
    ]
  }
  "values": {
    "abbr": "val",
    matchers: [
      ['""', 'EMPTY']
      ["''", 'EMPTY']
      ['NULL', 'NIL']
    ]
  }
  "parentheses": {
    "abbr": "parens",
    matchers: [
      ['(', 'OPEN']
      [')', 'CLOSED']
    ]
  }
  "logic": {
    abbr: "log",
    matchers: [
      "and"
      "or"
      # ["|", "UNION"]
    ]
  }

class Operator
  constructor: (@category_id, @category_abbr, matcher)->
    if matcher is undefined
      throw new Error('cannot match undefined operator value')
    if _.isString(matcher)
      @string = matcher
    else if _.isArray(matcher)
      [@string, @repr] = matcher
    else
      @string = matcher.string
      @repr = matcher.repr
      if matcher.regex
        @regex = new RegExp(matcher.regex)
    if !@repr
      @repr = @string.toUpperCase().replace(/-/g, '')
    @code = "#{@category_abbr}.#{@repr}"
    if @category_id is 'punctuation' and @string in [".", ".."]
      @code = @repr
    Operator.lookup[@code] = @

operators = []
operators.Kls = Operator

operators.load_operators = (local_params)->
  Operator.lookup = {}
  for category_id in local_params.categories
    category = local_params[category_id]
    abbr = category.abbr or category_id
    for matcher in category.matchers
      operators.push(new Operator(category_id, abbr, matcher))

operators.load_operators(params)

module.exports = operators
