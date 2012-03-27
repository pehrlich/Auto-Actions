# Auto Action

Start with a regular spine controller, and include.  This could be easily adapted not to require Spine.

```coffeescript
#my_controller.js.coffee:
  @include window.AutoAction
  hello_world: ()->
    alert('ok')
```

```html
<a data-click="hello_world">Hello World</a>
````

data-event_name works, where event_name is the name of a standard jquery event.  Currently supported: click, submit, focus, change, keydown.  Additions here are trivial.


## Extra Features:

### Event Target

```coffeescript
  new_contents: (target)->
    target.html('Replacement Contents')
```

```html
<a data-click="new_contents">Original Contents</a>
````

### Form Data:

```coffeescript
  set_fridge: (target, data)->
    data.refrigerator == 'open' # true
```

Use on a form or input element to have its data included.  Remember that the submit event specifically only gets triggered

```html
<form data-submit="set_fridge">
	<input name="refrigerator" value='open'>
</form>
```

### Callbacks:

before, callbacks are implemented, after and after_ajax (when deferred object returned) are in the pipeline.

```coffeescript
  # controller
  constructor ->
    before @extract_options, only: 'send_form'
  
  extract_options: (target, data)->
    target.disable()
```

### Transparent Ajax

When an action name is prefixed with get_ or post_, it will be treated as ajax appropriately.  Any form data or passed arguments will be sent to the a sensible URL.  The controller must respond to @resource() with an object that returns to url(method_name).  Any method with the ajax prefix removed and a status suffix of success, complete, or error will be used as a callback.

Additionally, a method window.ajax should be implemented which accepts an options hash.  This can be as simple as a passthrough to $.ajax

```coffeescript
# your library code:
window.ajax = $.ajax

# your controller:
  resource() ->
    User.find(1)

  # response after a post reqest to '/users/1/fridge'
  fridge_success: (target, data)->
    # data is the response data, not the form data
    refresh_fridge(data)
```

```html
<form data-submit="post_fridge">
	<input name="refrigerator" value='open'>
</form>
```

### Method Arguments 

Arguments can be seperated by commas, and will be given as strings as the first arguments to a method.  This means that all usages of an argumented method should employ the same number of arguments.

```coffeescript
  change_state: (state, target)->
    render(state)
```

Use on a form or input element to have its data included.  Remember that the submit event specifically only gets triggered

```html
<form data-submit="set_fridge">
	<input name="state, yellow" value='open'>
</form>
```

## Contributions welcome
[twitter.com/ehrlicp](twitter.com/ehrlicp)