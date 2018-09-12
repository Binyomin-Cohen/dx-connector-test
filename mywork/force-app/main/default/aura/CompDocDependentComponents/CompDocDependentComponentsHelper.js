({

  librariesAreDefined : function() {
    return typeof BW != 'undefined' && BW.LTCommon && BW.AlmCommon;
  },

  //Item-04393 Microsof Edge version 16 was not loading scripts right away
  ensureLibrariesAreDefined: function(retries, cb) {
    const maxRetries = 10;
    if (retries > maxRetries) {
      var pageMessageAddEvent = $A.get('e.c:pageMessageAdd');
      pageMessageAddEvent.setParams({
        'type' : 'error',
        'message' : 'An error occurred while loading the page. Please try again or contact your administrator for assistance.'
      });
      pageMessageAddEvent.fire();
    }
    else if (!this.librariesAreDefined && retries <= maxRetries) {
      setTimeout(function() {
        $A.getCallback(function(){
          ensureLibrariesAreDefined(retries + 1, cb);
        })
      }, 500);
    }
    else {
      cb();
    }
  },

  refreshComponents : function(component, event) {
    var documentedComponents = event.getParam("documentedComponents");
    if ($A.util.isUndefinedOrNull(documentedComponents)) {
      documentedComponents = component.get("v.allDocumentedComponents");
    } else {
      component.set("v.allDocumentedComponents", documentedComponents );
    }
    
    var filterChoice = event.getParam("relatedComponentsFilterChoice");
    if ($A.util.isUndefinedOrNull(filterChoice)) {
        // if the event does not have the filter choice, grab it from the select element on the page
        filterChoice = $('#related-components-filter-container .filter-values').val();
    }
    
    documentedComponents = this.chunkArray(documentedComponents.slice(0));
    for (var i = 0; i < documentedComponents.length; ++i) {
      documentedComponents[i] = JSON.stringify(documentedComponents[i]);
    }
    
    var action = component.get("c.queryDependentMembers");
    action.setParams({
      existingMembersStrings : documentedComponents,
      relatedComponentsFilterChoice : filterChoice,
    });
    action.setCallback(this, function(data) {
      var state = data.getState();

      if (state === "SUCCESS") {
        var result = data.getReturnValue();
        var savedComponentsResult = [];
        for (var i = 0; i < result.length; ++i) {
          savedComponentsResult = savedComponentsResult.concat(JSON.parse(result[i]));
        }

        this.applySortOrder(
          savedComponentsResult,
          component.get('v.currentSortKey'),
          component.get('v.currentSortKeyType'),
          component.get('v.currentSortDirection')
        );
        component.set('v.allDependentDocumentedComponents', savedComponentsResult);

        this.updateSelectedComponentsFromAllComps(component);
        this.getCurrentPageDependentComponents(component);
      } else if (state === "ERROR") {
        var errors = data.getError();
        if (errors) {
          if (errors[0] && errors[0].message) {
            // BW.ComponentSearch.renderSearchResults(errors[0].message);
            throw new Error("Error message: " + errors[0].message);
          }
        } else {
          throw new Error("Unknown error");
        }
      }

      component.set('v.firstResultSetProcessed', true);
    });
    $A.enqueueAction(action);
    
  },

  getTotalComponentRecordCount : function(component){
    var totalComponentsSize = component.get('v.allDependentDocumentedComponents').length;
    return totalComponentsSize;
  },

  getTotalPageCount : function(component){
    var currentPageSize = component.get("v.pageSize");
    var totalComponentsSize = this.getTotalComponentRecordCount(component);
    var totalEvenCountPages = Math.floor(totalComponentsSize/currentPageSize);
    var totalOddCountPages = (totalComponentsSize % currentPageSize) > 0;
    var totalPageCount = totalEvenCountPages + totalOddCountPages;
    return totalPageCount;

  },

  handlePageNavigation : function(component, event){
    if (component.isValid()){
      var totalPageCount = this.getTotalPageCount(component);
      var currentPageNumber = component.get("v.currentPageNumber");
      var navigationRequest = event.getParam('pagingDirection');
      var navigationPageNumberRequest = event.getParam('pageNumber');
      if (navigationPageNumberRequest > 0 && navigationPageNumberRequest <= totalPageCount){
        if (navigationPageNumberRequest != currentPageNumber){
          component.set("v.currentPageNumber", navigationPageNumberRequest);
        } else {
          this.getCurrentPageDependentComponents(component);
        }
      } else {
        if (currentPageNumber > 1 && navigationRequest === 'previous'){
          component.set("v.currentPageNumber", currentPageNumber - 1);
        } else if (currentPageNumber < totalPageCount && navigationRequest === 'next'){
          component.set("v.currentPageNumber", currentPageNumber + 1);
        }
      }
    }
  },

  getCurrentPageRows : function(){
    return $("#alm-container .dependent-components-table-content input.select-cb-delete");
  },

  getCurrentSelectedRowKeys : function(component){
    if (component.isValid()){
      var allSelected = component.get('v.selectedBacklogComponentIds');
      var allRows = this.getCurrentPageRows();
      for (var i = 0; i < allRows.length; i++){
        var rowBacklogComponentId = $(allRows[i]).data('backlog-component-id');
        if ($(allRows[i]).is(':checked')){
          if (allSelected.indexOf(rowBacklogComponentId) === -1){
            allSelected.push(rowBacklogComponentId);
          }
        } else {
          var currentDeSelectedIndex = allSelected.indexOf(rowBacklogComponentId);
          if (currentDeSelectedIndex > -1){
            allSelected.splice(currentDeSelectedIndex, 1);
          }
        }
      }
      component.set('v.selectedBacklogComponentIds', allSelected);
      return allSelected;
    }
  },

  getCurrentPageDependentComponents : function(component){
    // TODO: Determine if we should retain selections across pages and sorting. See Item-03667
    if (component.isValid()){
      var pageSize = component.get("v.pageSize");
      var currentPageNumber = component.get("v.currentPageNumber");
      var totalPageCount = this.getTotalPageCount(component);
      var childCompDocDependentComponentsTable = component.find('CompDocDependentComponentsTable');
      var allDependentDocumentedComponents = component.get("v.allDependentDocumentedComponents");
      var currentPageSelectedComponentCount = 0;
      var currentSelectedComponents = component.get('v.selectedBacklogComponentIds');
      var currentPageComponents = BW.LTCommon.getPageFromList(allDependentDocumentedComponents, currentPageNumber, pageSize);
      if (allDependentDocumentedComponents.length > 0 && currentPageComponents.length === 0){
        component.set("v.currentPageNumber", component.get("v.currentPageNumber") - 1);
        return;
      }

      for (var i = 0; i < currentPageComponents.length; i++){
        if (currentSelectedComponents && currentSelectedComponents.indexOf(currentPageComponents[i].component.Id) > -1){
          currentPageComponents[i].checked = true;
          currentPageSelectedComponentCount += 1;
        } else {
          currentPageComponents[i].checked = false;
        }
      }
      if (childCompDocDependentComponentsTable !== undefined){
        childCompDocDependentComponentsTable.set("v.currentPageDependentComponents", currentPageComponents );
      }

      this.updateListControls(component);

      var childPageBlockPanelSection = component.find('pageBlockPanelSection');

      var currentPageDependentComponentSize = childCompDocDependentComponentsTable !== undefined ?
          childCompDocDependentComponentsTable.get("v.currentPageDependentComponents").length : 0;
      childPageBlockPanelSection.set('v.pagingNavigationMessage',
          BW.LTCommon.getPaginationRecordCountMessage(allDependentDocumentedComponents.length, currentPageDependentComponentSize, currentPageNumber, pageSize)
      );

      childPageBlockPanelSection.set('v.enablePagingPrevious', currentPageNumber > 1);
      childPageBlockPanelSection.set('v.enablePagingNext', currentPageNumber < totalPageCount);
    }
  },

  applySortOrder : function(wrappers, sortKey, sortKeyType, sortDirection) {
    var sortMultiplier = (sortDirection === 'asc') ? 1 : -1;
    wrappers.sort(
      function(aWrapper, bWrapper){
        var aValue = BW.AlmCommon.getProperty(aWrapper, sortKey);
        var bValue = BW.AlmCommon.getProperty(bWrapper, sortKey);
        if (sortKeyType === "boolean") {
          if (aValue == bValue){
            return 0;
          } else if (aValue === true && !bValue) {
            return sortMultiplier;
          } else if (aValue === false && bValue) {
            return sortMultiplier*-1;
          }
        } else if (sortKeyType === "datetime") {
          return sortMultiplier * BW.LTCommon.compareByLastModifiedDate(
              {lastModifiedDate: aValue},
              {lastModifiedDate: bValue});
        }
        var aValueStr = (aValue || '');
        var bValueStr = (bValue || '');
        if (aValueStr.length === 0 && bValueStr.length  > 0){
          return 1;
        } else if (aValueStr.length > 0 && bValueStr.length  === 0){
          return -1;
        }
        var result = aValueStr.localeCompare(bValueStr);
        return result * sortMultiplier;
      }
    );
  },

  updateComponentSortOrder : function(component){
    if (component.isValid()){
      var currentPageNumber = component.get('v.currentPageNumber');
      var sortKey = component.get('v.currentSortKey');
      var sortKeyType = component.get('v.currentSortKeyType');
      var sortOrder = component.get('v.currentSortDirection');
      var allComponentWrappers = component.get('v.allDependentDocumentedComponents');
      this.applySortOrder(allComponentWrappers, sortKey, sortKeyType, sortOrder);
      component.set('v.allDependentDocumentedComponents', allComponentWrappers);
      if (currentPageNumber === 1){
        this.getCurrentPageDependentComponents(component);
      } else {
        component.set("v.currentPageNumber", 1);
      }
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

  updateSelectedComponentsFromAllComps: function (component) {
    var allComponentWrappers = component.get('v.allDependentDocumentedComponents'),
        selectedBacklogComponentIds = [];
    for (var i = 0; i < allComponentWrappers.length; i++) {
       var comp = allComponentWrappers[i];
       if (comp.checked) {
          selectedBacklogComponentIds.push(comp.component.Id)
       }
    }
    component.set('v.selectedBacklogComponentIds', selectedBacklogComponentIds);
  },

  addComponents : function(component, event) {
    component.set('v.enableActionButton', false);
    BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Component Documentation', 'Document Components', 'Component Documentation - Document Related Component');
    var checkedRowKeys,
        self = this;

    checkedRowKeys = component.get('v.allDependentDocumentedComponents').reduce(function(keys, result) {
      if (result.checked && !result.existsOnCurrentBacklog) {
        keys.push(result.key);
      }
      return keys;
    }, []).join(',');

    var params = {
      selectedComponentIdString : checkedRowKeys,
      backlogItemId : component.get('v.backlogItemId'),
      notes : ""
    };

    var createAction = component.get('c.createSelectedComponents');
    createAction.setParams(params);

    createAction.setCallback(this, function(data) {
      var options = {};
      options.cb = function() {
        self.fireSaveCompleteEvent();
      };
      options.errorCb = function(error) {
        BW.LTCommon.addPageMessage('error', error);
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    self.fireSaveBeginEvent();
    $A.enqueueAction(createAction);
  },

  rowSelect : function(component, event) {
    if (component.isValid() && event !== null && event !== undefined) {
      var dependentComponents = component.get('v.allDependentDocumentedComponents');
      var currentPageDependentComponents = BW.LTCommon.getPageFromList(dependentComponents, component.get('v.currentPageNumber'), component.get('v.pageSize'));

      var selectAll = event.getParam('selectAll');
      if (selectAll !== null && selectAll !== undefined) {
        for (var i = 0; i < currentPageDependentComponents.length; ++i) {
          currentPageDependentComponents[i].checked = selectAll;
          $('#select-cb-add-dependent-' + currentPageDependentComponents[i].component.Id).prop('checked', selectAll);
        }
        component.find('CompDocDependentComponentsTable').set('v.currentPageDependentComponents', currentPageDependentComponents);
      }

      component.set(
        'v.selectedBacklogComponentIds',
        dependentComponents
          .filter(function(dependentComponent) {
            return dependentComponent.checked;
          })
          .map(function(dependentComponent) {
            return dependentComponent.component.Id;
          })
      );

       this.updateListControls(component);
    }
  },

  updateListControls : function(component) {
    if (component.isValid() && !$A.util.isUndefinedOrNull(component.find('CompDocDependentComponentsTable'))) {
      var selectedDependentComponentIds = component.get('v.selectedBacklogComponentIds');
      var currentPageDependentComponentIds =
        BW.LTCommon.getPageFromList(component.get('v.allDependentDocumentedComponents'), component.get('v.currentPageNumber'), component.get('v.pageSize'))
        .map(function(currentPageDependentComponent) {
           return currentPageDependentComponent.component.Id;
        });
      var currentPageSelectedDependentComponentIds =
        selectedDependentComponentIds.filter(function(currentPageSelectedDependentComponent) {
          return currentPageDependentComponentIds.includes(currentPageSelectedDependentComponent);
        });

      if (selectedDependentComponentIds.length > 0) {
        component.set('v.enableActionButton', true);
        component.find('CompDocDependentComponentsTable').changeSelectAll(currentPageDependentComponentIds.length === currentPageSelectedDependentComponentIds.length);
      } else {
        component.set('v.enableActionButton', false);
        component.find('CompDocDependentComponentsTable').changeSelectAll(false);
      }
    }
  },

  chunkArray : function(arrayToChunk) {
    var chunkSize = 100;

    if (arrayToChunk.length < chunkSize) {
      return [arrayToChunk];
    }

    var chunkedArray = [];
    for (var i = 0; i < arrayToChunk.length; ++i) {
      if (i % chunkSize === 0) {
        chunkedArray.push([]);
      }

      chunkedArray[Math.floor(i / chunkSize)].push(arrayToChunk.shift());
    }

    return chunkedArray;
  }

});