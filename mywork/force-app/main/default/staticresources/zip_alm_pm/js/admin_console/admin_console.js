(function(global) {
  var init = function ($, AlmCommon) {
    "use strict";
    //on document ready
    $(function(){
      
      var beforeUnload = this.unloadPage;
      if (global.addEventListener) {
        global.addEventListener("beforeunload", beforeUnload);
      } else {
        attachEvent('onbeforeunload', beforeUnload);
      }

      $( "#sidebar li.parent a" ).on( "click", function(evt) {
        var $li = $(this).closest('li');
        $li.find("ul").toggle('slide', {
          direction : "up",
          duration: 400
        });
        $li.toggleClass('selected');
      });

      setActiveNav();
    });

    function setActiveNav() {
      var url = window.location.pathname;
      var $currentItem = $('#sidebar').find('a[data-url="'+url+'"]').closest('li');

      $currentItem.addClass('active').append('<div class="active-arrow" />');
      if ($currentItem.parents('li').hasClass('parent')) {
        $currentItem.parents('li').addClass('selected active').find('ul').show();
      }
    }
  }; // end init()

  if (typeof define !== 'undefined') {
    define(
      [
        'jquery',
        'jquery-blockUI',
        'js_alm_common',
      ], function() {

      var jQuery = arguments[0];
      var AlmCommon = arguments[2];

      var API = init(jQuery, AlmCommon);

      global.BW = global.BW || {};
      global.BW.AdminConsole = API;

      return API
    });
  } else {
    global.BW = global.BW || {};
    global.BW.AdminConsole = init(global.jQuery, global.BW.AlmCommon);
  }

})(this);
