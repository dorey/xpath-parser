_ = require('underscore')
log = (args...)-> console.log.apply(console, args)

operators = require('./operators')

module.exports = parse_expression = (input)->
  if _.isString(input)
    new Expression(str: input)
  else if _.isArray(input)
    new Expression(arr: input)
  else
    new Expression(input)

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

class Expression
  constructor: (params={})->
    if params.parent
      @parent = params.parent
      @__uniqueIdCnt = @parent.__uniqueIdCnt + 1
    else
      @__uniqueIdCnt = 0

    if params.str
      @parse_str(params.str)
    if params.arr
      @parse_arr(params.arr)

  _uniqueId: (suffix)->
    "#{suffix}#{@__uniqueIdCnt++}"

  parse_arr: (arr)->
    _asString = @object_to_str(arr)
    @toString = ()-> _asString
    @toObject = ()-> arr

  parse_str: (str)->
    @original = str
    _str = "#{@original}"
    @local_replacements = []

    # responsible for setting @dict, @predicates, @lookups
    # @operators, and @paths
    for prop in ['dict', 'predicates', 'lookups', 'operators', 'paths']
      if @parent
        @[prop] = _.clone(@parent[prop])
      else
        @[prop] = {}

    _str = @replace_consts(_str)

    # single quotes
    _str = @pull_out_wrapped_quotes(_str, false)

    # double quotes
    _str = @pull_out_wrapped_quotes(_str, true)
    _str = @convert_lookups(_str)

    @anonymized = "#{_str}"

    _str = @pull_out_predicates(_str)

    _str = @pull_out_xpaths(_str)
    _str = @pull_out_operators(_str)
    _str = @strip_whitespace(_str)
    _str = @pull_out_methods(_str)

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
    _unnested_object = @restore_predicates(_unnested_object)
    @as_structured_json = @move_method_arguments(_unnested_object)

    @toObject = ()=> @as_structured_json
    @toString = ()=> @object_to_str @as_structured_json


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

  pull_out_predicates: (_str)->
    unless _str.match(/[\[\]]/g)
      return _str
    # step1: convert A to B
    # A: ["x[y]z"]
    # B: ["x", ["y"], "z"]
    try
      _json = JSON.stringify(_str)
                  .replace(/\]/g, '"], "')
                  .replace(/\[/g, '", ["')
      _restructured = JSON.parse("[" + _json + "]")
    catch e
      throw new Error('unmatched brackets in predicate')
    smush = (arr, layer_n=0)=>
      _out = ""
      for item in arr
        if _.isArray(item)
          smushed = smush(item, layer_n + 1)
          if layer_n is 0
            ucode = @_uniqueId('PREDICATE')
            @predicates[ucode] = smush(item)
            _out += " #{ucode} "
          else
            _out += smushed
        else
          _out += item
      _out
    smush _restructured

  restore_predicates: (arr)->
    # _restore_predicates = (arr)=>
    out = []
    for item in arr
      if _.isArray(item)
        out.push(@restore_predicates(item))
      else if item of @predicates
        inner_predicate = @predicates[item]
        if inner_predicate
          _p = new Expression(str: inner_predicate, parent: @).toObject()
        else
          log item
          _p = []

        out.push(
          predicate: _p
        )
      else
        out.push(item)
    out

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
    for operator in operators
      if operator.category_id is "methods"
        continue
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

  pull_out_methods: (_str)->
    methods = do ->
      out = {}
      for op in operators when op.category_id is "methods"
        out[op.string] = op
      out
    _arr = _str.split(' ').map (item)->
      if methods[item]
        methods[item].code
      else
        item
    _arr.join(' ')

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

  object_to_str: (arr, join_with)->
    arr2s = (arr, join_with=' ')->
      out = []
      for item in arr
        if _.isString(item) and operators.Kls.lookup[item]
          out.push operators.Kls.lookup[item].string
        else if _.isString(item)
          out.push item
        else if item.method
          out.push "#{item.method}(#{arr2s(item.arguments, join_with)})"
        else if item.lookup
          out.push "${#{item.lookup}}"
        else if item.path
          out.push arr2s(item.path, '')
        else if item.predicate
          out.push "[ #{arr2s(item.predicate)} ]"
        else if _.isArray(item)
          out.push "(#{arr2s(item)})"
      out.join(join_with)
    arr2s arr, join_with

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
              method: operators.Kls.lookup[item].string,
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
    else if operators.Kls.lookup[_item]
      chunk_dotcode = _item
      @_value = operators.Kls.lookup[_item].string
      @dotcode = chunk_dotcode
      @csscode = _item.toLowerCase().replace('.', '-')
      @type = @csscode.split('-')[0]
    else
      @_value = _item
      @type = 'unk'
