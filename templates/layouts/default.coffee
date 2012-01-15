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
      @div "#bodyContents", ->
        @text @partial(@template, context: @context, args: layoutArgs)

      if @currentUser
        @div id: 'currentUser', style: "display: none", 'data-id': @currentUser._id, 'data-username': @currentUser.username
