module.exports.djbHash = (s) ->
  total = 0
  for i in [0 .. s.length - 1]
    total = (total * 33) + s.charCodeAt(i) & 0x7fffffff
  return total
