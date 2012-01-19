exports.template = (code, message, error) ->
  @p "ERROR #{code}. #{message}"
  if error
    @pre @h(error.stack or error)
