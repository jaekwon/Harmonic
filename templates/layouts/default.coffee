exports.template = ->
  @doctype 5
  @html ->
    @head ->
      @title @site.title
      @link type: "text/css", rel: "stylesheet", href: @staticFile("main.css")
      @script type: 'text/javascript', src: @staticFile("jquery/jquery.min.js")

    @body ->
      @h1 "~<i>!</i> riverpen..."
      @div "#bodyContents", ->
        @text @render(@template, @context, @args...)

      if @currentUser
        @div id: 'currentUser', style: "display: none", 'data-id': @currentUser._id, 'data-username': @currentUser.username
