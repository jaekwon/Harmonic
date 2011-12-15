exports.template = ->
  @doctype 5
  @html ->
    @head ->
      @title @site.title
      @link type: "text/css", rel: "stylesheet", href: @static_file("main.css")
      @script type: 'text/javascript', src: @static_file("jquery/jquery.min.js")

    @body ->
      @h1 "~<i>!</i> riverpen..."
      @div "#body_contents", ->
        @text @render(@template, @context, @args...)

      if @current_user
        @div id: 'current_user', style: "display: none", 'data-id': @current_user._id, 'data-username': @current_user.username
