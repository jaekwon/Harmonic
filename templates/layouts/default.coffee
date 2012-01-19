exports.template = ->
  layoutArgs = arguments
  @doctype 5
  @html ->
    @head ->
      @title @site.title
      @link type: "text/css", rel: "stylesheet", href: @staticFile("main.css")
      @script type: 'text/javascript', src: @staticFile("jquery/jquery.min.js")

    @body ->
      @h1 "harmonic"
      if @req.user?
        @text @h(@req.user.data.username)
      else
        @a href: @urlFor('auth:login'), 'Log in'
      @div "#bodyContents", ->
        @text @partial(@template, context: @context, args: layoutArgs)

      if @user
        @div id: 'user', style: "display: none", 'data-id': @user._id, 'data-username': @user.username
