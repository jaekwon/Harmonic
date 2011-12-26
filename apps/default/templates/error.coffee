exports.template = (code, message, error) ->
  @p "ERROR #{code}. #{message}"
  if error
    if error.stack
      @pre error.stack
    else
      @pre error
