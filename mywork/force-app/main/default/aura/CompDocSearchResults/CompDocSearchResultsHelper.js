({
  init : function(component) {
    this.PAGE_SIZE = component.get("v.pageSize");
    this.NUM_ROWS_PER_QUERY_FILTERED = 300;
    this.NUM_ROWS_PER_QUERY_DEFAULT = 25;
    this.COMPONENT_STATES = {
      'LOADING' : 'loading',
      'RESULTS_TABLE' : 'resultsTable',
      'RESULTS_TABLE_WAITING' : 'resultsTableWaiting',
      'NO_RESULTS_FOR_SEARCH' : 'noResultsForSearch',
      'NO_COMPS_IN_ORG' : 'noCompsInOrg'
    };
    component.set("v.COMPONENT_STATES", this.COMPONENT_STATES);

    this.initializeSearchParams(component);
    this.doInitialSearch(component);
  },

  initializeSearchParams : function(component) {
    component.set("v.searchParams", {
      pageSize : component.get("v.numComponentsPerQuery"),
      currentPage: 0
    });
  },

  // handlers and events
  handlePreviousPageRequest : function(component, event) {
    var currentPage = component.get("v.currentPage");
    if (currentPage > 1) {
      this.changePage(component, currentPage - 1);
    }
  },

  handleNextPageRequest : function(component, event) {
    if (this.retrievedResultsHaveMoreRowsForDisplay(component) ||
       (!component.get("v.currentSearchCompleted") && !this.searchResultsAreLoading(component))) {
      var nextPageNum = component.get("v.currentPage") + 1;
      this.changePage(component, nextPageNum);
    }

    if (this.shouldFetchNextPage(component)) {
      this.fetchNextPage(component, this, component.get("v.searchResultsVersion"));
    }
  },

  handleNewUnseenResults : function(component, event) {
    var results = event.getParam('results'),
        unseenResults,
        seenResults;

    unseenResults = BW.LTCommon.insertElementsIntoOrderedList(component.get("v.unseenResults"),
                                                              results, BW.LTCommon.compareByLastModifiedDate);

    // if first page of initial search is empty, no components exist in org.
    if (component.get("v.pagesFetched") === 1 && results.length === 0 &&
        component.get("v.searchResultsVersion") === 0) {
      component.set("v.componentsExistInOrg", false);
      component.set("v.componentState", component.get("v.COMPONENT_STATES").NO_COMPS_IN_ORG);
      return;
    }

    component.set("v.unseenResults", unseenResults);
    if (results.length === 0 || this.maxComponentsHaveBeenRetrieved(component)) {
      if (this.maxComponentsHaveBeenRetrieved(component)) {
        if(component.get("v.namespace")) {
          component.set("v.reachedMaxOffsetMessage", $A.get("$Label." + component.get("v.namespace") + ".More_Filtering_Required"));
        } else {
          component.set("v.reachedMaxOffsetMessage", $A.get("$Label.c.More_Filtering_Required"));
        }
      }
      component.set("v.currentSearchCompleted", true);
    }

    if (component.get("v.currentSearchCompleted")) {
      this.transferAllResultsFromUnseenToSeen(component);
    } else {
      this.transferPageFromUnseenToSeenResults(component);
    }

    if (component.get("v.currentPageResults").length > 0) {
      this.refreshViewState(component);
    } else {
      this.changePage(component, component.get("v.currentPage"));
    }

    if (this.shouldFetchNextPage(component)) {
      this.fetchNextPage(component, this, component.get("v.searchResultsVersion"));
    }
  },

  handleChildRowSelect : function(component) {
    if (!this.allSelectableRowsAreSelected(component)) {
      component.set("v.selectAll", false);
    }
  },

  handleAsyncSearchEvent : function(component, event) {
    if (component.get("v.componentsExistInOrg")) {

      if ( (event.getParam("selectedInstances").length > 0) || (event.getParam("selectedUsers").length > 0) ) {
        component.set("v.numComponentsPerQuery", this.NUM_ROWS_PER_QUERY_FILTERED);
      } else {
        component.set("v.numComponentsPerQuery", this.NUM_ROWS_PER_QUERY_DEFAULT);
      }

      var searchParams = {
        name : event.getParam("componentName"),
        type : event.getParam("componentType"),
        parentComponent : event.getParam("componentParentName"),
        selectedUsers : event.getParam("selectedUsers"),
        instances : event.getParam("selectedInstances"),
        pageSize : component.get("v.numComponentsPerQuery"),
        currentPage: 0
      };
      this.resetSearchAttributes(component);
      component.set("v.componentState", component.get("v.COMPONENT_STATES").LOADING);
      component.set("v.searchParams", searchParams);
      component.set("v.searchResultsVersion", component.get("v.searchResultsVersion") + 1);
      var existingComponentKeys = component.get("v.existingComponentKeys");
      if (!existingComponentKeys || (existingComponentKeys.length === 0) ) {
        this.doInitialSearch(component, this);
      } else {
        this.fetchNextPage(component, this, component.get("v.searchResultsVersion"))
      }
      this.changePage(component, 1);
    }
  },

  fireSaveBeginEvent : function() {
    var appEvent = $A.get("e.c:asyncSaveEvent");
    appEvent.setParams({ "isSaveComplete" : false });
    appEvent.fire();
  },

  fireSaveCompleteEvent : function() {
    var appEvent = $A.get("e.c:asyncSaveEvent");
    appEvent.setParams({ "isSaveComplete" : true });
    appEvent.fire();
  },

  // pagination helpers
  changePage : function(component, pageNumber) {
    component.set("v.currentPage", pageNumber);
    this.setCurrentPageResults(component);
    this.refreshViewState(component);
  },

  refreshViewState: function(component) {
    if (component.get("v.currentSearchCompleted") && component.get("v.seenResults").length === 0) {
      this.unblockTable();
      component.set("v.componentState", component.get("v.COMPONENT_STATES").NO_RESULTS_FOR_SEARCH);
    } else if (this.currentPageHasCompleteResultSet(component)) {
      this.unblockTable();
      component.set("v.componentState", component.get("v.COMPONENT_STATES").RESULTS_TABLE);
    } else {
      if (component.get("v.currentPageResults").length > 0) {
        this.blockTable();
        component.set("v.componentState", component.get("v.COMPONENT_STATES").RESULTS_TABLE_WAITING);
      } else {
        component.set("v.componentState", component.get("v.COMPONENT_STATES").LOADING);
      }
    }

    this.refreshSelectAll(component);
    this.setPagingNavigationMessage(component);
    this.refreshHasResultsSummaries(component);
  },

  currentPageHasCompleteResultSet : function(component) {
    var totalSeenResults = component.get("v.seenResults").length,
        currentPage = component.get("v.currentPage");
    if (component.get("v.currentSearchCompleted")) {
      return true;
    } else {
      return totalSeenResults >= (currentPage * this.PAGE_SIZE);
    }
  },

  shouldFetchNextPage: function(component) {
    return !(component.get("v.fetchInProgress") || component.get("v.currentSearchCompleted")
             || this.enoughPagesAreBuffered(component));
  },

  enoughPagesAreBuffered: function(component) {
    // TODO: change pages fetched to be dynamic based on the page-size.
    var pagesFetched = component.get("v.pagesFetched"),
        pagesRequired = component.get("v.currentPage") + component.get("v.NUM_PAGES_TO_BUFFER");
    return pagesFetched >= pagesRequired;
  },

  transferPageFromUnseenToSeenResults : function(component) {
    var recordsToTransfer,
        unseenResults = component.get('v.unseenResults'),
        seenResults = component.get('v.seenResults');

    recordsToTransfer = unseenResults.splice(0, this.PAGE_SIZE);
    this.flagDocumentedComponentsInResults(component, recordsToTransfer),
    component.set("v.unseenResults", unseenResults);
    component.set("v.seenResults", seenResults.concat(recordsToTransfer));
  },

  transferAllResultsFromUnseenToSeen : function(component) {
    var seenResults = component.get("v.seenResults"),
        unseenResults = component.get("v.unseenResults");
    this.flagDocumentedComponentsInResults(component, unseenResults);
    component.set("v.seenResults", seenResults.concat(unseenResults));
    component.set("v.unseenResults", []);
  },

  setCurrentPageResults : function(component) {
    if (this.currentPageHasCompleteResultSet(component)) {
      var currentPageResults = BW.LTCommon.getPageFromList(component.get("v.seenResults"),
                                                           component.get("v.currentPage"),
                                                           component.get("v.pageSize"));
      component.set("v.currentPageResults", currentPageResults);
    }
  },

  setPagingNavigationMessage : function(component) {
    var currentPageSize = component.get("v.currentPageResults").length,
        currentPageNumber = component.get("v.currentPage"),
        pageSize = component.get("v.pageSize"),
        numFormatFn = ($A.localizationService.formatNumber).bind($A.localizationService),
        totalComponents,
        pageMessage = '';

    if (component.get("v.componentState") === component.get("v.COMPONENT_STATES").NO_RESULTS_FOR_SEARCH ||
        component.get("v.componentState") === component.get("v.COMPONENT_STATES").NO_COMPS_IN_ORG ) {
      component.set("v.pagingNavigationMessage", '0 of 0');
    } else {
      if (component.get("v.seenResults").length === 0) {
        totalComponents = 0;
        pageSize = 0;
      } else if (!component.get("v.currentSearchCompleted")) {
        // If search isn't complete, we trick the pageMessage method into displaying 'of many'
        totalComponents = BW.LTCommon.MAX_COMPONENT_RECORD_COUNT_THRESHOLD + 1;
      } else {
        totalComponents = this.totalRowsRetrieved(component);
      }

      pageMessage = BW.LTCommon.getPaginationRecordCountMessage(totalComponents, currentPageSize,
                                                                currentPageNumber, pageSize, numFormatFn);
      component.set("v.pagingNavigationMessage", pageMessage);
    }
  },

  refreshHasResultsSummaries : function(component) {
    if (this.retrievedResultsHaveMoreRowsForDisplay(component)
        || !component.get("v.currentSearchCompleted")) {
      component.set("v.hasNextResults", true);
    } else {
      component.set("v.hasNextResults", false);
    }

    if (component.get("v.currentPage") <= 1) {
      component.set("v.hasPreviousResults", false);
    } else {
      component.set("v.hasPreviousResults", true);
    }
  },

  retrievedResultsHaveMoreRowsForDisplay : function(component) {
    var currentPage = component.get("v.currentPage");
    return this.totalRowsRetrieved(component) > (currentPage * this.PAGE_SIZE);
  },

  totalRowsRetrieved : function(component) {
    // Queries return extra rows with potentially older modified dates.
    // We need to keep these around, but not serve them up immediately.

    if (component.get("v.currentSearchCompleted")) {
      return component.get("v.seenResults").length + component.get("v.unseenResults").length;
    } else {
      return component.get("v.pagesFetched") * component.get("v.pageSize");
    }
  },

  maxComponentsHaveBeenRetrieved : function(component) {
    return (component.get("v.numComponentsPerQuery") * component.get("v.pagesFetched")) >=
        component.get("v.MAX_RETRIEVABLE_COMPONENTS");
  },

  setHasSelectedComponents : function(component, event) {
    var total = component.get("v.seenResults").filter(function(result) {
      return result.checked && !result.existsOnCurrentBacklog;
    }).length;
    component.set("v.hasSelectedComponents", total > 0);
  },

  flagDocumentedComponentsInResults : function(component, results) {
    var existingComponentKeys = component.get("v.existingComponentKeys");
    for(var i = 0; i < results.length; i++) {
      results[i].existsOnCurrentBacklog = (existingComponentKeys.indexOf(results[i].key) >= 0);
    }
    return results;
  },

  flagDocumentedComponents : function(component) {
    var seenResults =   component.get("v.seenResults"),
        unseenResults = component.get("v.unseenResults");

    this.flagDocumentedComponentsInResults(component, seenResults),
    component.set("v.seenResults", seenResults);

    this.setCurrentPageResults(component);
    this.changePage(component, component.get("v.currentPage"));
  },

  totalSelectedRowsOnPage : function(component) {
    var currentPageResults = component.get("v.currentPageResults");
    return currentPageResults.filter(function(result) {
      return result.checked && !result.existsOnCurrentBacklog;
    }).length;
  },

  totalUndocumentedRowsOnPage : function(component) {
    var currentPageResults = component.get("v.currentPageResults");
    return currentPageResults.filter(function(result) {
      return !result.existsOnCurrentBacklog;
    }).length;
  },

  allSelectableRowsAreSelected : function(component) {
    var selectedCount = this.totalSelectedRowsOnPage(component),
        undocumentedCount = this.totalUndocumentedRowsOnPage(component);
    return selectedCount === undocumentedCount && undocumentedCount > 0;
  },

  refreshSelectAll : function(component) {
    component.set("v.selectAll", this.allSelectableRowsAreSelected(component));
  },

  selectAllCurrentPageResults : function(component, event) {
    var currentPageResults = component.get("v.currentPageResults");
    component.set("v.selectAll", true);

    for(var i = 0; i < currentPageResults.length; i++) {
      if (!currentPageResults[i].existsOnCurrentBacklog) {
        currentPageResults[i].checked = true;
      }
    }
    component.set("v.currentPageResults", currentPageResults);
  },

  deselectAllCurrentPageResults : function(component, event) {
    var currentPageResults = component.get("v.currentPageResults");
    component.set("v.selectAll", false);

    for(var i = 0; i < currentPageResults.length; i++) {
      if (!currentPageResults[i].existsOnCurrentBacklog) {
        currentPageResults[i].checked = false;
      }
    }
    component.set("v.currentPageResults", currentPageResults);
  },

  changeCheckedComponentsToExisting : function(component) {
    var seenResults = component.get("v.seenResults");
    for(var i = 0; i < seenResults.length; i++) {
      if (seenResults[i].checked) {
        seenResults[i].checked = false;
        seenResults[i].existsOnCurrentBacklog = true;
      }
    }
  },

  unblockTable : function() {
    BW.AlmCommon.unblockUI('#component-search-table');
  },

  blockTable : function() {
    BW.AlmCommon.blockUI('#component-search-table');
  },

  searchResultsAreLoading : function(component) {
    return component.get("v.componentState") === component.get("v.COMPONENT_STATES").LOADING ||
      component.get("v.componentState") === component.get("v.COMPONENT_STATES").RESULTS_TABLE_WAITING;
  },

  // server-side component actions
  createSelectedComponents : function(component, event) {
    BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Component Documentation', 'Document Components', 'Document Components');
    var checkedRowKeys,
        self = this;
    var profileDocumented = false;
    
    if (component.get("v.hasSelectedComponents")) {
      component.set("v.hasSelectedComponents", false);

      checkedRowKeys = component.get("v.seenResults").reduce(function(keys, result) {
        if (result.checked && !result.existsOnCurrentBacklog) {
          keys.push(result.key);
          if (result.component.Type__c === 'Profile' && !profileDocumented) {
            profileDocumented = true;
          }
        }
        return keys;
      }, []).join(',');

      var params = {
        selectedComponentIdString : checkedRowKeys,
        backlogItemId : component.get("v.backlogItemId"),
        notes : ""
      };

      var createAction = component.get("c.createSelectedComponents");
      createAction.setParams(params);

      createAction.setCallback(this, function(data) {
        var options = {};
        options.cb = function() {
          self.changeCheckedComponentsToExisting(component);
          self.fireSaveCompleteEvent();
          self.setHasSelectedComponents(component, event);
          if (profileDocumented) {
            BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Component Documentation', 'Document Profile');
          }
        };
        options.errorCb = function(error) {
          BW.LTCommon.addPageMessage('error', error);
        };
        BW.LTCommon.auraCallbackHandler(data, options);
      });
      self.fireSaveBeginEvent();
      $A.enqueueAction(createAction);
    }
  },

  doInitialSearch : function(component) {
    var self = this,
        getKeysAction = component.get("c.getExistingComponentKeys"),
        searchResultsVersion = component.get("v.searchResultsVersion"),
        params = {
          backlogItemId : component.get("v.backlogItemId")
        };

    component.set("v.componentState", component.get("v.COMPONENT_STATES").LOADING);
    this.changePage(component, 1);

    getKeysAction.setParams(params);

    getKeysAction.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var existingKeys = data.getReturnValue();
        component.set("v.existingComponentKeys", existingKeys.split(','));
        self.fetchNextPage(component, self, searchResultsVersion);
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(getKeysAction);
  },

  refreshDocumentedComponentsInSeenResults : function(component, event) {
    var self = this;
    var getKeysAction = component.get("c.getExistingComponentKeys");
    var params = {
      backlogItemId : component.get("v.backlogItemId")
    };

    getKeysAction.setParams(params);

    getKeysAction.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var existingKeys = data.getReturnValue();
        component.set("v.existingComponentKeys", existingKeys.split(','));
        self.flagDocumentedComponents(component);
        self.setHasSelectedComponents(component, event);
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(getKeysAction);
  },

  resetSearchAttributes : function(component) {
    if (component.isValid()){
      component.set("v.pagesFetched", 0);
      component.set("v.currentSearchCompleted", false);
      component.set("v.currentPage", 1);
      component.set("v.currentPageResults", []);
      component.set("v.seenResults",        []);
      component.set("v.unseenResults",      []);
      component.set("v.reachedMaxOffsetMessage", "");
    }
  },

  fetchNextPage : function(component, helper, resultsVersionBeforeFetch) {
    var searchParams = component.get("v.searchParams") || {},
        action = component.get("c.doPageSearch");

    component.set("v.fetchInProgress", true);
    searchParams.currentPage = component.get("v.pagesFetched") + 1;

    action.setParams({
      searchParamsJSON : JSON.stringify(searchParams)
    });

    action.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var resultsVersionAfterFetch = component.get("v.searchResultsVersion"),
            pagesFetched = component.get("v.pagesFetched") + 1,
            searchResults = data.getReturnValue().results,
            newUnseenResultsEvt;

        component.set("v.fetchInProgress", false);
        if (resultsVersionBeforeFetch === resultsVersionAfterFetch && component.get("v.componentsExistInOrg")) {
          component.set("v.pagesFetched", pagesFetched);
          newUnseenResultsEvt = $A.get("e.c:asyncLoadEvent");
          newUnseenResultsEvt.setParam("results", searchResults);
          newUnseenResultsEvt.fire();
        }
      };

      options.errorCb = function(error) {
        component.set("v.fetchInProgress", false);
        component.set("v.currentSearchCompleted", true);
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(action);
  },
});
