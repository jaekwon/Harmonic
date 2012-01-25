exports.template = (code, message, error) ->
  @p "ERROR #{code}. #{message}"
  if error
    @pre ->
      @text @h(error.stack or error)
