(function(global) {
  global.BW = global.BW || {};
  global.BW.AdminConsole = BW.AdminConsole || {};
  var init = function ($, AlmCommon) {
    "use strict";
      //on document ready
      $(function(){
        enableStatusDrag();
        $( ".save-btn" ).on( "click", save);
        $( "#main-content" ).on( "click", "#inactive-statuses-content .remove", removeStatus);
        doWindowResize();
        $(window).on("resize", doWindowResize);
      });

      function enableStatusDrag() {
        $( "#active-statuses-content .item-tile").draggable({
          revert: "invalid",
          refreshPositions: false,
          containment: "#main-container",
          helper : "clone",
          cursor: "move",
          opacity: .7,
          zIndex: 100,
          start: function(event, ui) {
            $(this).hide();
            $(this).after('<div class="drag-src-placeholder"/>');
          },
          stop: function(event, ui) {
            $("#active-statuses-content").find(".drag-src-placeholder").remove();
            $(this).show();
          }
        });

        $('#inactive-statuses').droppable({
          accept: "#active-statuses-content .item-tile",
          hoverClass: "drag-hover",
          drop: function( event, ui ) {

            AlmCommon.setHasUnsavedChanges(true);
            $('#inactive-statuses-content').append(ui.draggable.clone().show());

            //Let draggable finish cleaning up after itself before deleting element
            window.setTimeout(function(){
              ui.draggable.remove();
            }, 100);
          }
        });
      }

      function removeStatus() {
        var $statusTile = $(this).closest('.item-tile'),
         statusToRemove = $statusTile.find('span').text(),
         inserted = false;
        $( "#active-statuses-content .item-tile").each(function(){
          var status = $(this).find('span').text();
          if (statusToRemove < status) {
            $(this).before($statusTile);
            inserted = true;
            return false;
          }
        });
        if (!inserted) {
          $( "#active-statuses-content").append($statusTile);
        }
        $statusTile.addClass('restored').removeClass('restored', 3000);
        enableStatusDrag();
      }

      function save() {
        var inactiveStatuses = $('#inactive-statuses .item-tile span').map(function() {
          return $(this).text();
        }).get();
        AlmCommon.blockUI('#main-content');
        saveInactiveStatuses(inactiveStatuses, function(result, event) {
          AlmCommon.setHasUnsavedChanges(false);
          AlmCommon.unblockUI('#main-content');
          if (!event.status && event.message){
            AlmCommon.showError( event.message);
          }
        });
      }

    function doWindowResize() {
      AlmCommon.windowResize('#main-content .primary-column-content', '#main-content  .secondary-column-content', 190, 72);
    }
  };

  if (typeof define !== 'undefined') {
    define(
      [
        'jquery',
        'js_alm_common',
      ], function() {

      var jQuery = arguments[0];
      var AlmCommon = arguments[1];

      var API = init(jQuery, AlmCommon);
      global.BW.AdminConsole.BacklogStatus = API;

      return API
    });
  } else {
    global.BW.AdminConsole.BacklogStatus = init(global.jQuery, BW.AlmCommon);
  }

})(this);
