({
  init : function(component, event, helper) {
    helper.init(component, event);
    BW.AlmCommon.enableShiftSelect({
      container : "#alm-container",
      parent : '.selected-comp-cb',
      selector : '.search-components-table-content label.checkbox span'
    });
  },

  handleSearchResultsSaveEvent : function(component, event, helper) {
    helper.createSelectedComponents(component, event);
  },

  handleSearchEvent : function(component, event, helper) {
    helper.handleAsyncSearchEvent(component, event);
  },

  handleAsyncLoadEvent : function(component, event, helper) {
    helper.handleNewUnseenResults(component, event);
  },

  handlePagingRequest : function(component, event, helper) {
    var pagingDirection = event.getParam('pagingDirection');

    if (pagingDirection === 'previous' && component.get("v.hasPreviousResults")) {
      helper.handlePreviousPageRequest(component, event);
    } else if(pagingDirection === 'next' && component.get("v.hasNextResults")) {
      helper.handleNextPageRequest(component, event);
    }
  },

  handleChildRowSelect : function(component, event, helper) {
    var selectAll = event.getParam('selectAll');
    if (selectAll === true) {
      helper.selectAllCurrentPageResults(component, event);
    } else if (selectAll === false) {
      helper.deselectAllCurrentPageResults(component, event);
    } else {
      component.set('v.selectAll', true);
    }
    helper.handleChildRowSelect(component);
    helper.setHasSelectedComponents(component, event);
  },

  refreshComponents : function(component, event, helper) {
    if (event.getParam('isSaveComplete')) {
      helper.refreshDocumentedComponentsInSeenResults(component, event);
    }
  }

});
