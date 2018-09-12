({
  doInitialQuery : function(component, event, helper) {
    var self = this,
        firstQueryOpts  = {offset: 0,  pageSize: 100,    getTotalComponentCount: true};

    self.queryDocumentedComponents(component, firstQueryOpts, function(queryResult) {
      if (queryResult.totalDocumentedComponents) {
        component.set("v.totalDocumentedComps", queryResult.totalDocumentedComponents);
      }
      self.setAllDocumentedComps(component, queryResult.results);

      // we can't make this conditional on queryResult.hasMore until the server-side issue
      // with incomplete queries is resolved.
      self.refreshComponents(component, null);
    });
  },

  queryDocumentedComponents : function(component, queryOpts, cbFn) {
    var backlogItemId = component.get("v.backlogItemId"),
        action = component.get("c.queryDocumentedComponents"),
        self = this;

    queryOpts.backlogItemId = backlogItemId;
    action.setParams(queryOpts);

    action.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        cbFn(data.getReturnValue());
      };

      options.errorCb = function(error) {
        var errors = data.getError();
        if (errors) {
          if (errors[0] && errors[0].message) {
            throw new Error("Error message: " + errors[0].message);
          }
        } else {
          throw new Error("Unknown error");
        }
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(action);
  },

  setAllDocumentedComps : function(component, results) {
    var selectAllComponentsOnInit = component.get('v.selectAllComponentsOnInit'),
        sortKey = component.get('v.currentSortKey'),
        sortKeyType = component.get('v.currentSortKeyType'),
        firstResultSetProcessed = component.get('v.firstResultSetProcessed'),
        sortOrder = component.get('v.currentSortDirection');

    results = results.map(function(result) {
      if (selectAllComponentsOnInit && (!component.get('v.disableDeletedComponents') || !result.isDeleted)) {
        result.checked = true;
      }
      return result;
    });
    
    this.applySortOrder(results, sortKey, sortKeyType, sortOrder);
    component.set('v.allDocumentedComponents', results);

    if (component.get("v.firstResultSetProcessed")) {
      //Fire an event to initialize the dependent components
      this.fireFindDependentComponentsEvent(results);
      component.set("v.totalDocumentedComps", results.length);
    }

    this.updateSelectedComponentsFromAllDocumentedComponents(component);
    this.getCurrentPageDocumentedComponents(component);
    component.set("v.firstResultSetProcessed", true);
  },

  refreshComponents : function(component, event) {
    var backlogItemId = component.get("v.backlogItemId"),
        action = component.get("c.getBacklogComponentsDiffs"),
        self = this;

    var allBacklogComponentIds = component.get('v.allDocumentedComponents').map(function(documentedComponent) {
      return documentedComponent.backlogComponent.Id;
    });

    action.setParams({
      backlogItemId : backlogItemId,
      knownBacklogComponentIds : allBacklogComponentIds
    });
    // swap for LTCommon
    action.setCallback(this, function(data) {
      var state = data.getState();

      if (state === "SUCCESS") {
        var componentDiffResult = data.getReturnValue(),
            allDocumentedComponents = this.applyDocumentedComponentDiff(component, componentDiffResult);
        self.setAllDocumentedComps(component, allDocumentedComponents);
      } else if (state === "ERROR") {
        var errors = data.getError();
        if (errors) {
          if (errors[0] && errors[0].message) {
            throw new Error("Error message: " + errors[0].message);
          }
        } else {
          throw new Error("Unknown error");
        }
      }

      //resetting to having no unsaved changes, to override any changes due to initialization
      this.fireUnsavedChangesEvent(component, false);
      
      component.set('v.firstResultSetProcessed', true);
    });
    $A.enqueueAction(action);
  },

  fireUnsavedChangesEvent : function(component, isUpdated) {
    var evt = component.getEvent("unsavedPageEvent");
    evt.setParam("isPageUpdated", isUpdated);
    evt.fire();
  },

  applyDocumentedComponentDiff : function(component, componentDiff) {
    var currentDocumentedComponents = component.get('v.allDocumentedComponents');

    var deletedComponentsSet = {};
    componentDiff.deletedComponents.forEach(function(deletedComponentId) {
      deletedComponentsSet[deletedComponentId] = deletedComponentId;
    });

    var allComponents = componentDiff.addedComponents;
    currentDocumentedComponents.forEach(function(documentedComponent) {
      if (deletedComponentsSet[documentedComponent.backlogComponent.Id] === undefined) {
        allComponents.push(documentedComponent);
      }
    });

    return allComponents;
  },

  addEventHandlers : function(component, helper) {
    BW.AlmCommon.enableShiftSelect({
      container : "#alm-container",
      parent : '.select-cb',
      selector : '.documented-components-table-content label.checkbox span',
      defaultCallback : function($rows, isChecked) {
        var selectedBacklogComponentIds = $rows.map(function () {
          return $(this).data("backlog-component-id");
        });
        if (isChecked) {
          helper.selectDocumentedComponents(component, selectedBacklogComponentIds);
        } else {
          helper.deselectDocumentedComponents(component, selectedBacklogComponentIds);
        }
      }
    });
  },

  openNotesModal : function(component, componentRecord) {
    if (!componentRecord || !componentRecord.backlogComponent ||
        !componentRecord.backlogComponent.Id || !componentRecord.componentName) {
      return;
    }

    var notesModal = component.find("comp-doc-notes-modal");
    notesModal.set('v.enableApply', false);
    notesModal.set('v.noteText', componentRecord.notes || "");
    notesModal.set('v.noteName', componentRecord.componentName);
    notesModal.set('v.backlogComponentId', componentRecord.backlogComponent.Id);

    BW.AlmCommon.displayModal({
      content: $("#notes-modal"),
      width : '75%',
      height : '75%',
      overflow: 'visible'
    });
  },

  updateNotes : function(component, eventPayload) {
    this.closeNotesModal();
    if (!eventPayload || !eventPayload.backlogComponentId) {
      return;
    }

    var backlogComponentId = eventPayload.backlogComponentId,
        backlogComponentNotesValue = eventPayload.notes,
        totalComponents = component.get('v.allDocumentedComponents');
    for (var i = 0; i < totalComponents.length; i++) {
      if (totalComponents[i].backlogComponent.Id === backlogComponentId) {
        totalComponents[i].notes = backlogComponentNotesValue;
        break;
      }
    }
    component.set('v.allDocumentedComponents', totalComponents);
    this.getCurrentPageDocumentedComponents(component);
  },

  closeNotesModal : function() {
    BW.AlmCommon.unblockUI();
  },

  updateSelectedComponents : function(component, event) {
    if (component.isValid()) {
      if (component.get("v.enableActionButton")) {
        component.set('v.enableActionButton', false);
        this.fireSaveBeginEvent();
        var deleteAction = component.get("c.deleteSelectedComponents");
        var backlogComponentdIdsToDelete = component.get('v.selectedBacklogComponentIds');
        deleteAction.setParams({
          backlogComponentIds : backlogComponentdIdsToDelete
        });
        deleteAction.setCallback(this, function(data) {
          var state = data.getState();
          this.fireSaveCompleteEvent();
          component.set('v.selectAllChecked', false);
          if (state === "SUCCESS") {
            component.set('v.selectedBacklogComponentIds', []);
          } else if (state === "ERROR") {
            var errors = data.getError();
            if (errors) {
              if (errors[0] && errors[0].message) {
                throw new Error("Error message: " + errors[0].message);
              }
            } else {
              throw new Error("Unknown error");
            }
          }
        });
        $A.enqueueAction(deleteAction);
      }
    }
  },

  getTotalComponentRecordCount : function(component) {
    var totalComponentsSize = component.get('v.allDocumentedComponents').length;
    return totalComponentsSize;
  },

  getTotalPageCount : function(component) {
    var currentPageSize = component.get("v.pageSize");
    var totalComponentsSize = this.getTotalComponentRecordCount(component);
    var totalEvenCountPages = Math.floor(totalComponentsSize/currentPageSize);
    var totalOddCountPages = (totalComponentsSize % currentPageSize) > 0;
    return totalEvenCountPages + totalOddCountPages;
  },

  handlePageNavigation : function(component, event) {
    if (component.isValid()) {
      var totalPageCount = this.getTotalPageCount(component);
      var currentPageNumber = component.get("v.currentPageNumber");
      var navigationRequest = event.getParam('pagingDirection');
      var navigationPageNumberRequest = event.getParam('pageNumber');
      if (navigationPageNumberRequest > 0 && navigationPageNumberRequest <= totalPageCount) {
        if (navigationPageNumberRequest !== currentPageNumber) {
          component.set("v.currentPageNumber", navigationPageNumberRequest);
        } else {
          this.getCurrentPageDocumentedComponents(component);
        }
      } else {
        if (currentPageNumber > 1 && navigationRequest === 'previous') {
          component.set("v.currentPageNumber", currentPageNumber - 1);
        } else if (currentPageNumber < totalPageCount && navigationRequest === 'next') {
          component.set("v.currentPageNumber", currentPageNumber + 1);
        }
      }
    }
  },

  getCurrentPageComponents : function(component) {
    return BW.LTCommon.getPageFromList(
        component.get("v.allDocumentedComponents"),
        component.get("v.currentPageNumber"),
        component.get("v.pageSize"));
  },

  getCurrentPageDocumentedComponents : function(component) {
    // TODO: Determine if we should retain selections across pages and sorting. See Item-03667
    if (component.isValid()) {
      var pageSize = component.get("v.pageSize");
      var totalDocumentedComps = component.get("v.totalDocumentedComps");
      var currentPageNumber = component.get("v.currentPageNumber");
      var totalPageCount = this.getTotalPageCount(component);
      var childCompDocDocumentedComponentsTable = component.find('CompDocDocumentedComponentsTable');
      var allDocumentedComponents = component.get("v.allDocumentedComponents");
      var currentSelectedComponents = component.get('v.selectedBacklogComponentIds');
      var currentPageComponents = BW.LTCommon.getPageFromList(allDocumentedComponents, currentPageNumber, pageSize);
      
      if (allDocumentedComponents.length > 0 && currentPageComponents.length === 0) {
        component.set("v.currentPageNumber", component.get("v.currentPageNumber") - 1);
        return;
      }

      this.setCurrentPageCompsChecked(component, currentPageComponents, currentSelectedComponents);

      if (childCompDocDocumentedComponentsTable !== undefined) {
        childCompDocDocumentedComponentsTable.set("v.currentPageDocumentedComponents", currentPageComponents );
      }

      var currentPageDocumentedComponentSize = childCompDocDocumentedComponentsTable !== undefined ?
          childCompDocDocumentedComponentsTable.get("v.currentPageDocumentedComponents").length : 0;
      
      var childPageBlockPanelSection = component.find('pageBlockPanelSection');    
      childPageBlockPanelSection.set('v.pagingNavigationMessage',
          BW.LTCommon.getPaginationRecordCountMessage(totalDocumentedComps, currentPageDocumentedComponentSize, currentPageNumber, pageSize)
      );
      childPageBlockPanelSection.set('v.enablePagingPrevious', currentPageNumber > 1);
      childPageBlockPanelSection.set('v.enablePagingNext', currentPageNumber < totalPageCount);
    }
  },

  setCurrentPageCompsChecked: function(component, currentPageComponents, currentSelectedComponents) {
    var currentPageSelectedComponentCount = 0;
    var componentsMarkedAsDeletedCount = 0;
    
    currentPageComponents.forEach( function(cpComp){
      if (cpComp.isDeleted) {
        componentsMarkedAsDeletedCount += 1;
      }
      if (currentSelectedComponents && currentSelectedComponents.indexOf(cpComp.backlogComponent.Id) > -1) {
        cpComp.checked = true;
        currentPageSelectedComponentCount += 1;
      } else {
        cpComp.checked = false;
      }

    });
    this.setSelectAll(component, currentPageComponents, currentPageSelectedComponentCount, componentsMarkedAsDeletedCount);
  },
  
  setSelectAll: function(component, currentPageComponents, currentPageSelectedComponentCount, componentsMarkedAsDeletedCount) {
    var allSelectedOnPage = component.get('v.disableDeletedComponents') === true ?
      currentPageSelectedComponentCount > 0 && currentPageSelectedComponentCount === currentPageComponents.length - componentsMarkedAsDeletedCount:
      currentPageSelectedComponentCount > 0 && currentPageSelectedComponentCount === currentPageComponents.length;
  
    component.set('v.selectAllChecked', allSelectedOnPage);
  },
  
  applySortOrder : function(wrappers, sortKey, sortKeyType, sortDirection) {
    var sortMultiplier = (sortDirection === 'asc') ? 1 : -1;
    wrappers.sort(
      function(aWrapper, bWrapper) {
        var aValue = BW.AlmCommon.getProperty(aWrapper, sortKey);
        var bValue = BW.AlmCommon.getProperty(bWrapper, sortKey);
        if (sortKeyType === "boolean") {
          if (aValue === bValue) {
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
        if (aValueStr.length === 0 && bValueStr.length  > 0) {
          return 1;
        } else if (aValueStr.length > 0 && bValueStr.length  === 0) {
          return -1;
        }
        var result = aValueStr.localeCompare(bValueStr);
        return result * sortMultiplier;
      }
    );
  },

  updateComponentSortOrder : function(component) {
    if (component.isValid()) {
      var currentPageNumber = component.get('v.currentPageNumber');
      var sortKey = component.get('v.currentSortKey');
      var sortKeyType = component.get('v.currentSortKeyType');
      var sortOrder = component.get('v.currentSortDirection');
      var allComponentWrappers = component.get('v.allDocumentedComponents');
      this.applySortOrder(allComponentWrappers, sortKey, sortKeyType, sortOrder);
      component.set('v.allDocumentedComponents', allComponentWrappers);
      if (currentPageNumber === 1) {
        this.getCurrentPageDocumentedComponents(component);
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

  fireFindDependentComponentsEvent : function(documentedComponents) {
    var appEvent = $A.get("e.c:findDependentComponentsEvent");
    if (appEvent) {
      appEvent.setParams({ "documentedComponents" : documentedComponents });
      appEvent.fire();
    }
  },

  fireSaveCompleteEvent : function() {
    var appEvent = $A.get("e.c:asyncSaveEvent");
    appEvent.setParams({ "isSaveComplete" : true });
    appEvent.fire();
  },

  updateSelectedComponentsFromAllDocumentedComponents: function (component) {
    var allComponentWrappers = component.get('v.allDocumentedComponents'),
        selectedBacklogComponentIds = [];
    for (var i = 0; i < allComponentWrappers.length; i++) {
      var comp = allComponentWrappers[i];
      if (comp.checked) {
        selectedBacklogComponentIds.push(comp.backlogComponent.Id);
      }
    }
    component.set('v.selectedBacklogComponentIds', selectedBacklogComponentIds);
  },

  updateAllDocumentedComponentsFromSelectedComponents: function (component) {
    var allComponentWrappers = component.get('v.allDocumentedComponents'),
        selectedBacklogComponentIds = component.get('v.selectedBacklogComponentIds');
    for (var i = 0; i < allComponentWrappers.length; i++) {
      var comp = allComponentWrappers[i];
      if ( (selectedBacklogComponentIds.indexOf(comp.backlogComponent.Id) > -1) && (!comp.checked) ) {
        allComponentWrappers[i].checked = true;
      } else if ( (selectedBacklogComponentIds.indexOf(comp.backlogComponent.Id) === -1) && comp.checked ) {
        allComponentWrappers[i].checked = false;
      }
    }
    component.set('v.allDocumentedComponents', allComponentWrappers);
  },

  handleSelectDocumentedComponent : function (component, backlogComponentId) {
    if ( component.get('v.selectedBacklogComponentIds').indexOf(backlogComponentId) === -1 ) {
      this.selectDocumentedComponents(component, [backlogComponentId]);
    } else {
      this.deselectDocumentedComponents(component, [backlogComponentId]);
    }
    this.toggleActionButton(component);
    this.getCurrentPageDocumentedComponents(component);
  },

  handleSelectAllDocumentedComponents : function (component, select) {
    var currentPageComponents = this.getCurrentPageComponents(component),
        backlogComponentIds = [];

    for (var i = 0; i < currentPageComponents.length; i++) {
      if (!(component.get('v.disableDeletedComponents') === true && currentPageComponents[i].isDeleted )){
        backlogComponentIds.push( currentPageComponents[i].backlogComponent.Id );
      }
    }

    if (select) {
      this.selectDocumentedComponents(component, backlogComponentIds);
    } else {
      this.deselectDocumentedComponents(component, backlogComponentIds);
    }
    this.toggleActionButton(component);
    this.getCurrentPageDocumentedComponents(component);
  },

  selectDocumentedComponents : function(component, backlogComponentIds) {
    var selectedIds = component.get('v.selectedBacklogComponentIds');

    for (var k = 0; k < backlogComponentIds.length; k++) {
      var backlogComponentId = backlogComponentIds[k],
          index = selectedIds.indexOf(backlogComponentId);

      if (index === -1 ) {
        selectedIds.push(backlogComponentId);
      }
    }
    component.set('v.selectedBacklogComponentIds', selectedIds);
    this.updateAllDocumentedComponentsFromSelectedComponents(component);
    this.toggleActionButton(component);
  },

  deselectDocumentedComponents : function(component, backlogComponentIds) {
    var selectedIds = component.get('v.selectedBacklogComponentIds');

    for (var k = 0; k < backlogComponentIds.length; k++) {
      var backlogComponentId = backlogComponentIds[k],
          index = selectedIds.indexOf(backlogComponentId);

      if (index > -1 ) {
        selectedIds.splice(index, 1);
      }
    }
    component.set('v.selectedBacklogComponentIds', selectedIds);
    this.updateAllDocumentedComponentsFromSelectedComponents(component);
    this.toggleActionButton(component);
  },

  toggleActionButton : function(component) {
    var selectedIds = component.get('v.selectedBacklogComponentIds');
    if ( selectedIds.length > 0 && !component.get('v.enableActionButton') ) {
      component.set('v.enableActionButton', true);
    } else if ( !selectedIds.length && component.get('v.enableActionButton') ) {
      component.set('v.enableActionButton', false);
    }
  }

});