_ = require('underscore')
log = (args...)-> console.log.apply(console, args)

parse_expression = (input)->
  if _.isString(input)
    new Expression(str: input)
  else if _.isArray(input)
    new Expression(arr: input)
  else
    new Expression(input)
module.exports = parse_expression

###
begin "operators"
###
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

operators_by_code = {}

class Operator
  @lookup = {}
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
    operators_by_code[@code] = @

Operator.lookup = operators_by_code

operators = []
for category_id in params.categories
  category = params[category_id]
  abbr = category.abbr or category_id
  for matcher in category.matchers
    operators.push(new Operator(category_id, abbr, matcher))

operators.kls = Operator
operators.operator_list = operators
operators.operators_by_code = operators_by_code

###
Begin parse_expression
###

_contains = (str, it)->
  str.indexOf(it) isnt -1
_strStrip = (str)->
  str.replace /^\s+|\s+$/g, ""
_replace_dict_items = (_str, dict, wrap=false)->
  for key, val of dict
    if wrap
      _str = _str.replace(key, "#{wrap}#{val}#{wrap}")
    else
      _str = _str.replace(key, val)
  _str

LOOKUP_REGEX = /^lookup\#(.*)$/
PATH_REGEX = /^path\#(.*)$/
STRIP_COMMAS = false
ESCAPED_CHARACTERS = {
  __ESC_DBL_QT__: '\\"'
  __ESC_SNG_QT__: "\\'"
}

operator_list = operators

class Expression
  constructor: (params={})->
    @uniqueIdCnt = 0
    if params.str
      @parse_str(params.str)
    if params.arr
      @parse_arr(params.arr)

  object_to_str: (arr, join_with)->
    arr2s = (arr, join_with=' ')->
      out = []
      for item in arr
        if _.isString(item) and operators_by_code[item]
          out.push operators_by_code[item].string
        else if _.isString(item)
          out.push item
        else if item.method
          out.push "#{item.method}(#{arr2s(item.arguments, join_with)})"
        else if item.lookup
          out.push "${#{item.lookup}}"
        else if item.path
          out.push arr2s(item.path, '')
        else if _.isArray(item)
          out.push "(#{arr2s(item)})"
      out.join(join_with)
    arr2s arr, join_with


  parse_arr: (arr)->
    _asString = @object_to_str(arr)
    @toString = ()-> _asString
    @toObject = ()-> arr

  parse_str: (str)->
    @original = str
    _str = "#{@original}"
    @local_replacements = []
    @dict = {}
    @lookups = {}
    @operators = {}
    @paths = {}

    _str = @replace_consts(_str)

    # single quotes
    _str = @pull_out_wrapped_quotes(_str, false)

    # double quotes
    _str = @pull_out_wrapped_quotes(_str, true)
    _str = @convert_lookups(_str)

    @anonymized = "#{_str}"

    _str = @pull_out_xpaths(_str)
    _str = @pull_out_operators(_str)
    _str = @strip_whitespace(_str)

    _str = _replace_dict_items(_str, @operators, false)
    _str = _replace_dict_items(_str, @paths, false)
    _str = _replace_dict_items(_str, @lookups, false)

    @chunked = for chunk in _strStrip(_str).split(' ')
      chunk = _replace_dict_items(chunk, @dict, "'")
      chunk
    @items = @chunked.map (item)=>
      new ParsedChunk(item, parentLine: @)
    _as_json = JSON.stringify(_.pluck(@items, 'as_json'))
    _unnested_object = @_hacky_restructure_json(_as_json)
    @as_structured_json = @move_method_arguments(_unnested_object)
    @toObject = ()=> @as_structured_json
    @toString = ()=> @as_structured_json

  _uniqueId: (suffix)->
    "#{suffix}#{@uniqueIdCnt++}"

  replace_consts: (_str)->
    for key, val of ESCAPED_CHARACTERS
      _str = _str.replace(val, key)
    _str

  pull_out_wrapped_quotes: (_str, single=false)->
    quote_char = if single then "'" else '"'
    matcher = ///
      (#{quote_char}(.*?)#{quote_char})
    ///
    mtch = _str.match matcher
    if mtch and mtch.length > 0
      _key = @_uniqueId('REPLACESTR')
      _val = mtch[2]
      @local_replacements.push(_key)
      @dict[_key] = _replace_dict_items(_val, ESCAPED_CHARACTERS)
      _str = _str.replace(mtch[1], _key)
      _str = @pull_out_wrapped_quotes(_str, single)
    _str

  pull_out_xpaths: (_str)->
    while mtch = _str.match ///
          (  # optionally start with '.', '..', current(), or instance(...)
            current\(\)
            |
            instance\([^\)]+\)
            |
            \.
            |
            \.\.
          )?
          (
            \/      # each section starts with "/"
            (
              \.\.  # double dot
              |
              \w+
              |
              \*
            )
          )+
        ///
      path_repl = @_uniqueId('PATH')
      path_str = mtch[0]
      _str = _str.replace(path_str, path_repl)
      @paths[path_repl] = "path##{path_str}"
    _str

  convert_lookups: (_str)->
    mtch = _str.match ///
        ^(.*?)
        \$\{(.+?)\}
        (.*)$
      ///
    if mtch and mtch.length > 0
      _key = @_uniqueId('LOOKUPMTCHR')
      _val = """lookup##{mtch[2]}"""
      @lookups[_key] = _val
      insertion = _key
      _str = "#{mtch[1]}#{insertion}#{mtch[3]}"
      _str = @convert_lookups(_str)
    _str

  pull_out_operators: (_str)->
    for operator in operator_list
      if operator.regex
        _str = _str.replace(operator.regex, " #{operator.code} ")
        continue
      loop_count = 0
      uniquestr = false
      while _contains(_str, operator.string)
        unless uniquestr
          uniquestr = @_uniqueId('OPERATOR')
          @operators[uniquestr] = operator.code
        loop_count++
        _str = _str.replace(operator.string, " #{operator.code} ")
        if loop_count > 500
          throw new Error("infinite while loop")
    _str

  strip_whitespace: (_str)->
    _str = _strStrip(_str)
    while _contains(_str, '  ')
      _str = _str.replace('  ', ' ')
    _str

  _hacky_restructure_json: (json_str)->
    ###
    this converts the flat array to a JSON string, replaces the
    occurrences of "parens.OPEN" and "parens.CLOSED" with [ and ]
    and then converts it back to an array
    ###
    try
      newstr = json_str.replace(/"parens\.OPEN"/g, '[')
                  .replace(/"parens\.CLOSED"/g, ']')
                  .replace(/\[,/g,'[')
                  .replace(/,\]/g,']')

      if STRIP_COMMAS
        newstr = newstr.replace(/"punc\.COMMA",/g, '')
      return JSON.parse(newstr)
    catch e
      throw new Error('unmatched parentheses')

  move_method_arguments: (arr)->
    move_args = (arr)->
      if !_.isArray(arr) or (arr.length is 0)
        return arr
      out = []
      n = 0
      push_arg = ->
        item = arr[n]
        next_item = arr[n + 1]
        if _.isString(item) and item.match(/^method\.(.*)$/) and _.isArray(next_item)
          out.push({
              method: operators_by_code[item].string,
              arguments: move_args(next_item),
            })
          next_item = false
          # move forward by 1
          n++
        else if _.isArray(item)
          out.push(move_args(item))
        else
          out.push(item)

      while n < arr.length
        push_arg(n)
        n++
      out
    move_args arr


parse_expression.Kls = Expression

class ParsedChunk
  constructor: (_item, {@parentLine})->
    @as_json = _item
    @atts = []
    if _item.match(LOOKUP_REGEX)
      _mtch = _item.match(LOOKUP_REGEX)
      @_lookup_key = _mtch[1]
      @_value = "lookup##{@_lookup_key}"
      @as_json = { lookup: @_lookup_key }
      @dotcode = "xpath.LOOKUP"
      @csscode = @dotcode.toLowerCase().replace('.', '-')
      @type = 'lookup'
    else if _item.match(PATH_REGEX)
      _mtch = _item.match(PATH_REGEX)
      @_path = _mtch[1]
      @dotcode = "xpath.PATH"
      @csscode = @dotcode.toLowerCase().replace('.', '-')
      # current() and instance('id') are currently very fragile, and only
      # work to pass tests when they are at the beginning of the path and
      # have identical arguments
      if @_path.match(/^current\(\)/)
        @as_json = path: [{
          method: 'current',
          arguments: [],
          }, @_path.replace(/^current\(\)/, '')]
      else if @_path.match(/^instance\([^\)]+\)/)
        matched = @_path.match(/^instance\(([^\)]+)\)(.*)$/)
        @as_json = {
          path: [
            {
              method: 'instance',
              arguments: [matched[1]]
            },
            matched[2]
          ]
        }
      else
        @as_json = { path: @_path }
    else if operators_by_code[_item]
      chunk_dotcode = _item
      @_value = operators_by_code[_item].string
      @dotcode = chunk_dotcode
      @csscode = _item.toLowerCase().replace('.', '-')
      @type = @csscode.split('-')[0]
    else
      @_value = _item
      @type = 'unk'