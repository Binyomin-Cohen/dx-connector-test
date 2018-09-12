({
  refreshComponents : function(component, event, helper) {
    var isSaveComplete = event.getParam("isSaveComplete");
    if (isSaveComplete === true) {
      helper.refreshComponents(component, event, helper);
    }
  },

  doInit : function(component, event, helper) {
    helper.addEventHandlers(component, helper);
    helper.doInitialQuery(component, event, helper);
  },

  handleUpdateComponentsEvent : function(component, event, helper) {
    helper.updateSelectedComponents(component, event);
  },

  handleLoadCompleteRequest : function(component, event, helper){
    helper.getCurrentPageDocumentedComponents(component);
  },

  handlePagingRequest : function(component, event, helper) {
    helper.handlePageNavigation(component, event, helper);
  },

  handleNewPageRequest : function(component, event, helper) {
    helper.getCurrentPageDocumentedComponents(component);
  },

  handleSortKeyChange : function(component, event, helper) {
    helper.updateComponentSortOrder(component);
  },

  handleRowSelectEvent : function(component, event, helper) {
    const selectAll = event.getParam("selectAll"),
          rowId = event.getParam("rowId");
    if ( selectAll === true || selectAll === false ) {
      helper.handleSelectAllDocumentedComponents(component, selectAll);
    } else if ( rowId ) {
      helper.handleSelectDocumentedComponent(component, rowId);
    }
  },

  handleModalEvent : function(component, event, helper) {
    const modalType = event.getParam('modalType'),
          modalAction = event.getParam('action');

    if (modalType === "notes") {
      if ( modalAction === "open" ) {
        helper.openNotesModal(component, event.getParam('payload'));
      } else if ( modalAction === "apply" ) {
        helper.updateNotes(component, event.getParam('payload'));
      } else if ( modalAction === "close" ) {
        helper.closeNotesModal();
      }
    }
  }

});
