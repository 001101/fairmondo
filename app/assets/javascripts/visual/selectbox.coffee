
document.Fairmondo.selectboxit = ->
  $('select').selectBoxIt
    autoWidth: false
  $('body').on 'click', 'span.selectboxit-container', (e) ->
    $('span.selectboxit-container').parents().not('#cboxLoadedContent').css('overflow', 'visible')

$(document).ready document.Fairmondo.selectboxit
$(document).ajaxStop document.Fairmondo.selectboxit
