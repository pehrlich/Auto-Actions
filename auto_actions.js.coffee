window.AutoAction = {

  # todo: deprecate action keyoword in favor of click
  events: # by specifying tagnames and events, we allow html5 form validation
    "click  a[data-action], li[data-action], i[data-action], img[data-action], div[data-action]":   'auto_action'
    "click  input[type=button][data-action]": 'auto_action'
    "click  [data-click]":               'auto_whatever'
    "change input[type=checkbox][data-action]": 'auto_checkbox'
    "change select[data-action]":             'auto_select'
    "submit form[data-action]":               'auto_form'
    "focus [data-focus]":                     'auto_focus'
    "keydown [data-keydown]":                 'auto_whatever'
    "click [data-toggle]":                    'auto_toggle'
    "submit [data-submit]":                   'auto_whatever'


  extract_options: (array)->
    if _.isObject _.last(array)
      array.pop()


  parse_args: (string)->
    _.map string.split(','), (term)-> term.replace(/[ ]/g, '')

  figure_condition: (options)->
    if options.if
      options.if
    else if options.only
      (action, method_args...)->
        method_ids = Array.wrap options.only
        _.include(method_ids, action)
    else if options.except
      (action, method_args...)->
        method_ids = Array.wrap options.except
        not _.include(method_ids, action)
    else
      () -> true


  # key value stores: {method_id: condition}
  _before_filters: {}
  _after_filters: {}
#  _after_ajax_filters: {}

  # usage:
  # @before 'tweak_data', 'button_shirt', {only: 'invite_users'}
  # the methods should be strings, and will be converted to @tweak_data, for example
  # options can be only, except, and if.  If will be passed the same arguments as the method, but preceeded
  # by a string of the method name

  before: (methods...)->
    options = @extract_options(methods)
    condition = @figure_condition(options)

    before_filters = {}
    for method_id in methods
      before_filters[method_id] = condition

    _.merge(@_before_filters, before_filters)


  filters_for: (filters, args...)->
    out = []
    for method_id, condition in filters
      if condition(args)
        out.push method_id

  # returns the valid before filters based upon action name
  # expects to be passed action (string) and the args that would be passed to the regular method
  run_filters: (filters, args...)->
    for method_id in @filters_for(filters)
      method_id(args)


  # This is used in the controller action, in emulation of rails
  # It configures a request, and can only be called once per action
  # These only work if active controller is self.  Ie, not on stream
  ajax: (options)->
    if @_request_options
      throw "@post/@get can only be called once per action"
    options ||= {}
    @_request_options = options

  post: (options)->
    options ||= {}
    options.type = 'post'
    @ajax(options)

  get: (options)->
    options ||= {}
    options.type = 'get'
    @ajax(options)





  # the active controller is passed the action, context is maintained
  run_action: (event, options)->
    options ||= {}

    target = options.target || $(event.currentTarget || event.target)

    # todo: before_validate callback

    if target
      # todo: allow custom hooks here
      if target.is('form') && !target.valid()
        console.log 'debug: Form validation did not pass'
        # for some reason, the submission doesn't go through when invalid by default
        # we return anyway, we don't want all those callbacks going off
        return false

      if target.filter('[data-confirm]').length
        return unless prompt (target.data('confirm') || "Are you sure?")




    # todo: deprecate options.data in favor of checking data by default
    form_data = options.data || target.nomData()
    event_type = options.type || event.type

    prevent_default = options.prevent_default
    if prevent_default == undefined && (prevent_default = target.data('preventdefault')) == undefined
      prevent_default = true


    return if target.hasClass 'disabled'


    ajax_status('done') # remove failed ajax symbol
    # used for onerror debugging purposes:
    window.last_click = action

    args = @parse_args target.data(event_type)
    action = args.shift()

    # find JSON in args:
#    console.log 'parsing args', args
#    for argument in args
#      try
#        argument = $.parseJSON(argument)
#      catch SyntaxError
#        console.log 'syntax error on', argument
#    console.log '..done', args




    # first after given args
    args.push(target) if target

    accessory = $("[for='#{action}']")
    args.push accessory if accessory.length

    args.push(form_data) unless _.isEmpty(form_data)


    unless action
      return true

    if action == "stop_propagation"
      event.stopPropagation()
      return

    if prevent_default
      event.preventDefault()

    controller = if @active_controller then @active_controller(target) else @

    unless callback = controller[action]
      # if the action has a prefixed name, assume total defaults
      # now that we know the action, we can also remove the prefix
      # in before/after filters, the action will appear w/o prefix

      if action.slice(0, 5) == 'post_'
        action = action.slice(5)
        console.log 'action being set', action
        callback = (target, data)=>
          @post()

      else if action.slice(0, 4) == 'get_'
        action = action.slice(4)
        callback = (target, data)=>
          @get()

      else
        message = "unfound action #{action} on controller"
        console.log message, controller
        throw message

    console.log "auto action #{action} #{args}", 'target:', target, 'form_data:', form_data

    # todo deprecate
    if before_filter = controller['before_filter']
      before_filter.apply(controller, args)

    @run_filters(@_before_filters, action, args)

    result = callback.apply(controller, args)



    if @_request_options
      # given back an object, make an ajax request
      console.log 'making automatic ajax request', @_request_options

      @_request_options.type ||= 'get'
      @_request_options.data ||= form_data
      unless @_request_options.url

        if controller.resource && (resource = controller.resource())
          # use the resource's route if there is a resource
          # note: we remove /update to get correct REST endpoint. (spine bug)
          console.log 'url before replace', controller.resource().url(action)
          @_request_options.url = controller.resource().url(action).replace(/\/update$/, '').replace(/\/new\/create/, '')

        else if path = controller.className
          # use the controller name as the default route otherwise
          # todo: invent conventions for turning classNames in to URLs.
          @_request_options.url = "/#{path}/#{action}"
        else
          console.log "Couldn't guess request URL for #{action}.  Resourece:", resource, "className:", path
          throw "Couldn't guess request URL for #{action}"

#      console.log 'looking for', "#{action}_success", controller["#{action}_success"]
      if success = controller["#{action}_success"]
        # we bind to the controller so you don't have to!
        @_request_options.success ||= (args...)->
          # javascript's native `arguments' is an object, not an array
          # luckily coffeescript has no such BS
          # http://debuggable.com/posts/turning-javascript-s-arguments-object-into-an-array:4ac50ef8-3bd0-4a2d-8c2e-535ccbdd56cb
          args.unshift(target)
          success.apply(controller, args)

      if error = controller["#{action}_error"]
        @_request_options.error ||= (args...)->
          args.unshift(target)
          success.apply(controller, args)

      console.log 'added callbacks to', @_request_options

      # todo: move to filter
      # todo: after filter for re enable
      target.disable() if target

      result = ajax @_request_options
      @_request_options = undefined


    if result and result['then']
      for method_id in @filters_for(@_after_filters, action, args)
        result.then (args...)->
          # add target to the default xhr arguments
          args.unshift(target)
          method_id.apply(controller, args)

      # todo: deprecate
      if after_filter = controller['after_filter']
        # deferred object returned.  After filter is belayed until ajax response
        # todo: keep context
        result.then (args...)->
          args.unshift(target)
          after_filter.apply(controller, args)
    else
      @run_filters(@_after_filters, action, args)
      # todo: deprecate
      if after_filter = controller['after_filter']
        after_filter.apply(controller, args)



  # deprecated
  auto_action: (event)->
    @run_action event, {
      type: 'action'
    }

  # deprecated
  auto_focus: (event)->
    @run_action event, {
      type: 'focus'
    }

  auto_widget: (event)->


  auto_whatever: (event)->
    console.log 'auto whatever', this, arguments
    # this should be used for other events without obtrusive default behavior
    # such as focus, keypresses, and so on

    @run_action event, {
      prevent_default: _.include(['click', 'submit'], event.type)
    }


  auto_select: (event)->
    # todo: convert to nomData & deprecate
    @run_action(event, {
      data: $(event.target).val(),
      type: 'action'
    })

  auto_checkbox: (event)->
    # todo: convert to nomData & deprecate in favor of auto_whatever
    @run_action event, {
      type: 'action',
      data: ($(event.target).filter(':checked').length > 0)
    }

  # give data-toggle=selector to an element.
  auto_toggle: (event)->
    event.preventDefault()
    target = $(event.target)
    selector = target.data("toggle")
#    args = @parse_args()
    # could alternatively use @$
    el = $(selector)
    console.log 'toggling', target, selector, el
    unless el.length
      console.warn "auto toggle no results for selector #{selector}"
    el.toggleClass('open')


}