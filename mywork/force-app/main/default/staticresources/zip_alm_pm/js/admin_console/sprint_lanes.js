var BW = BW || {};
BW.AdminConsole = BW.AdminConsole || {};
BW.AdminConsole.SprintLanes = (function ($) {
  "use strict"
  //on document ready
  $(function(){
    BW.AdminConsole.ColumnConfig.setConfig({
      sortableStop : function () {
        $('#sprint-complete-help').remove();
        $('.draggable-column')
          .removeClass('complete-column')
          .last()
          .addClass('complete-column')
          .append(templates["admin_sprint_lanes_complete"].render({}));
      }
    });
    BW.AdminConsole.ColumnConfig.enableColumnDrag();
  });

  var api = {};
  return api;
}(jQuery));

