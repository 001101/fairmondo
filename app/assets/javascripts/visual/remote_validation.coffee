remoteValidate = ->
  $('.l-main').on 'change keyup', '.JS-remote-validate-blur', validateRemotely

$(document).ready remoteValidate
$(document).ajaxStop remoteValidate

validateRemotely = (event) ->
  setTimeout -> # to allow JS-enforce-input-constraints to do it's thang
    target = event.target
    $target = $(target)
    params_from_name = target.name.slice(0, -1).split('[') # e.g. line_item[requested_quantity] => ['line_item', 'requested_quantity']
    value = target.value
    unless value is $target.attr('data-validation-allow') or value is '' # allow specific inputs. maybe make this regex compatible
      model = params_from_name[0]
      field = params_from_name[1]
      additional_params = $target.attr('data-validation-params')
      additional_params = if additional_params then "?#{additional_params}" else ''

      $.ajax
        type: 'POST'
        url: "/remote_validations/#{model}/#{field}/#{value}.json#{additional_params}"
        dataType: 'json'
        global: false
        success: (response) ->
          # reset in case error messages get chained
          $target.parent().removeClass 'error'
          $target.siblings('.inline-errors').remove()

          if $target.attr('data-validation-save-on-success') is 'true' and response.errors.length < 1
            $target.parents('form').submit()
          else if response.errors.length > 0 # add an error message if one exists
            #$.each response.errors, (index, error) -> console.log "#{target.name}: #{error}"
            $target.parent().addClass 'error'
            new_error = $("<p class='inline-errors hidden'>#{response.errors[0]}</p>")
            $target.after new_error
            document.Fairnopoly.setQTipError new_error

  , 1 # setTimeout: 1 millisecond wait
