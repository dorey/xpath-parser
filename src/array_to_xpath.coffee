log = (args...)->
  console.log("\n****\n")
  console.log.apply(console, args)

_ = require('underscore')

SPACE_PADDING =
  "+": " + "
  "-": " - "
  ",": ", "
  "=": " = "
  "<=": " <= "
  ">=": " >= "
  "!=": " != "
  "and": " and "
  "or": " or "

DEFAULT_FNS =
  $lookup: (param)->
    "${#{param}}"

# ins_and_outs = []

array_to_xpath = (outer_arr, _fns={})->
  # outer_arr_copy = JSON.parse(JSON.stringify(outer_arr))
  """
  This is a complicated method to do a couple simple tasks:

  * flatten an array of xpathy-items
  * iterate through the array of xpathy items and convert objects to
    strings
     - allows configurable functions (beginning with "$") to determine
       how those objects are translated to strings
  * continue to iterate until all objects are converted to strings

  This shouldn't need much modification, but if necessary, it's
  recommended you run and edit the tests as well.
  """
  fns = _.extend({}, DEFAULT_FNS, _fns)

  # a boolean to break out of the while loop
  _needs_parse = true

  # arr2x can be recursively called
  arr2x = (arr)->
    out = []
    if _.isArray arr
      # recurse
      for item in arr
        out.push arr2x(item)
    else if _.isString(arr) or _.isNumber(arr)
      # parameter is string or number and can be added directly
      out.push arr
    else if _.isObject arr
      # parameter is object and should be expanded
      keys = _.keys(arr).sort()
      if keys.length > 0
        _needs_parse = true
      for key in keys
        # skip keys that begin with '#' as comments
        if key.search(/^#/) isnt -1
          continue
        # handle keys that begin with '$' as transformable
        else if key.search(/^\$/) isnt -1
          if key not of fns
            throw new Error("Transform function not found: #{key}")
          out.push fns[key].call(null, arr[key])
        else
          # discard all other keys and recurse through the values
          out.push arr2x(arr[key])
    out

  while _needs_parse
    _needs_parse = false
    outer_arr = arr2x outer_arr

    # _needs_parse will be true iff an object was present and
    # needed to be expanded

  out_string = ""
  flattened = _.flatten outer_arr
  for n in [0...flattened.length]
    p = flattened[n]
    if p of SPACE_PADDING
      out_string += SPACE_PADDING[p]
    else
      out_string += p
  # ins_and_outs.push([outer_arr_copy, out_string])
  out_string

# array_to_xpath.log_ins_and_outs = ()->
#   console.log(JSON.stringify(_.zip(ins, outs)))

module.exports =
  array_to_xpath: array_to_xpath