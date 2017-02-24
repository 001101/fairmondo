###
   Copyright (c) 2012-2017, Fairmondo eG.  This file is
   licensed under the GNU Affero General Public License version 3 or later.
   See the COPYRIGHT file for details.
###

$(document).ready ->
  newsletter_input = $('#user_newsletter_input')

  if newsletter_input.length > 0
    newsletter_input.hide()
    $.getJSON '/toolbox/newsletter_status', (result) ->

      checked = if result.subscribed then 'check' else 'uncheck'
      $('#user_newsletter').iCheck checked

      newsletter_input.show()
