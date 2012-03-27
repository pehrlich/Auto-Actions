$.fn.nomData = ->
  ret = {}
  for key in this.serializeArray()
    ret[key.name] = key.value

  # $.fn.serializeArray ignores file inputs
#  if (file_input = this.find('input[name=file]')).length && (file = file_input.get(0).files[0])
    # this will fail on ie 8: http://stackoverflow.com/questions/6306674/get-file-from-input
    # for use with jquery.upload
#    ret['file'] = file

  ret
