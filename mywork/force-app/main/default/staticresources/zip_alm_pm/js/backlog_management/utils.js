(function() {
  "use strict";
  var init = function($) {
    
    var VERTICAL_FILTER_PANEL_OFFSET = 290;
    
    function doWindowResize() {
      var HORIZONTAL_OFFSET = 52;
      var OPEN_FILTER_TRAY_HORIZONTAL_OFFSET = HORIZONTAL_OFFSET + 282;
      $('#alm-table-panel').width($(window).width() - (!$('#filter-pane-handle').hasClass("close") ? HORIZONTAL_OFFSET : OPEN_FILTER_TRAY_HORIZONTAL_OFFSET) );
      $('#backlog-filter-panel .page-block-panel-body').css('max-height', $(window).height() - VERTICAL_FILTER_PANEL_OFFSET );
      $("#alm-container, .banner-wrap").width($(window).width()-20);
      
      
      var $table = $('#alm-table-panel .alm-table');
      if (!$table.hasClass('col-resized')) {
        $table.css('width', '100%');
      }
    }
    
    return {
      VERTICAL_FILTER_PANEL_OFFSET : VERTICAL_FILTER_PANEL_OFFSET,
      doWindowResize : doWindowResize
    };
    
  };

  define([
    'jquery'
  ], function() {
    var jQuery = arguments[0];
    return init(jQuery);
  });
})();