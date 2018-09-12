var BW = BW || {};
BW.AdminConsole = BW.AdminConsole || {};
/**
 * Javascript for the ColumnConfig visualforce component. This depends on a js function
 * being defined as saveColumns(Array, Function). This function should call a remote action
 */
BW.AdminConsole.ColumnConfig = (function ($, AlmCommon) {
  "use strict";

  var config = { sortableStop : function() {}};

    //on document ready
    $(function(){
      enableColumnDrag();
      updateDefaultDrag();
      $( ".save-btn" ).on( "click", save);
      $( "#main-content" ).on( "click", "#active-columns-content .remove", removeColumn);
      $( "#reset-columns" ).on( "click", resetColumns);

      var helpContent = templates["admin_backlog_column_help"].render({});
      $( "#admin-page-help" ).tooltip({ content: helpContent, items : "img"});

      doWindowResize();
      $(window).on("resize", doWindowResize);
    });

    function enableColumnDrag() {
      var activeScrollAreas = [];
      $( "#unused-columns-content .item-tile").draggable({
        revert: "invalid",
        refreshPositions: false,
        connectToSortable: "#active-columns-content",
        containment: "#main-content",
        helper : "clone",
        opacity: .7,
        zIndex: 100,
        drag: function(event, ui) {
          AlmCommon.handleDroppableScroll(event, ui, activeScrollAreas);
        },
        start: function(event, ui) {
          $(this).hide();
          $(this).after('<div class="drag-src-placeholder"/>');
          activeScrollAreas = AlmCommon.buildDroppableScrollAreas('#active-columns-content');
        },
        stop: function(event, ui) {
          $("#unused-columns-content").find(".drag-src-placeholder").remove();
          $(this).show();
        },
      });

      $("#active-columns-content").sortable({
          containment: "#alm-container",
          items: "> div.draggable-column",
          placeholder: "drop-placeholder",
          scrollSpeed : 20,
          scrollSensitivity : 40,
          helper: "clone",
          revert: "true",
          tolerance: "pointer",
          stop: function (event, ui) {
            AlmCommon.setHasUnsavedChanges(true);
            if (ui.item.closest('.draggable-column').length == 0) {
              ui.item.removeAttr('style');
              ui.item.wrap('<div class="draggable-column" />');
            }
            config.sortableStop();
            updateDefaultDrag();
          },
          receive: function(event, ui) {
            window.setTimeout(function () {
              ui.sender.remove();
            }, 100);
          },
          over: function(event, ui) {
            $('#active-columns .default-drag-helper').hide();
          },
          out: function(event, ui) {
            updateDefaultDrag();
          }
      });
      config.sortableStop();
    }

    /**Get non default columns*/
    function getCustomizedColumns() {
      return $('#active-columns .draggable-column').not('.default');
    }

    /**
     * hide or show the default drag column based on current state of the active columns
     */
    function updateDefaultDrag() {
      var showDefault = getCustomizedColumns().length == 0;
      if (showDefault) {
        $('#active-columns .default-drag-helper').show();
      } else {
        $('#active-columns .default-drag-helper').hide();
      }
    }

    function removeColumn() {
      var $tile = $(this).closest('.item-tile');
      restoreColumn($tile);
      enableColumnDrag();
      updateDefaultDrag();
      AlmCommon.setHasUnsavedChanges(true);
    }

    function restoreColumn($tile) {
      var statusToRemove = $tile.find('span').text(),
       inserted = false;
      $tile.removeAttr('style');
      $tile.closest('.draggable-column').remove();
      $( "#unused-columns-content .item-tile").each(function(){
        var status = $(this).find('span').text();
        if (statusToRemove < status) {
          $(this).before($tile);
          inserted = true;
          return false;
        }
      });
      if (!inserted) {
        $( "#unused-columns-content").append($tile);
      }
      $tile.addClass('restored').removeClass('restored', 3000);
    }

    function resetColumns() {
      getCustomizedColumns().find('.item-tile').each(function() {
        restoreColumn($(this));
      });
      enableColumnDrag();
      updateDefaultDrag();
      AlmCommon.setHasUnsavedChanges(true);
    }

    function save() {
      var fieldNames = $('#active-columns .draggable-column .item-tile').map(function() {
        return $(this).data('name');
      }).get();
      AlmCommon.blockUI('#main-content');
      saveColumns(fieldNames, function(result, event) {
        AlmCommon.setHasUnsavedChanges(false);
        AlmCommon.unblockUI('#main-content');
        if (!event.status && event.message){
          AlmCommon.showError( event.message);
        }
      });
    }

    function setConfig(options) {
      config = $.extend(config, options);
    }

    function doWindowResize() {
      var OFFSET = 545,
       $activeColsContent = $('#active-columns-content');

      $activeColsContent.width($(window).width() - OFFSET);
      AlmCommon.windowResize('#main-content .primary-column-content', '#main-content  .secondary-column-content', 190, 72);
    }
  var api = {
    enableColumnDrag : enableColumnDrag,
    setConfig : setConfig
  };
  return api;
}(jQuery, BW.AlmCommon));
