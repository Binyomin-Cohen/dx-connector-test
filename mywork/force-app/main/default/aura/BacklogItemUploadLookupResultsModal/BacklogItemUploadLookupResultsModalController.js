({
  hideModal : function(component, event, helper) {
    var modal = $(event.target).closest('.alm-modal');
    $.unblockUI(modal);
  }
})
