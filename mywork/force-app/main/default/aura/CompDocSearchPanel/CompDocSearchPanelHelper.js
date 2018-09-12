({
  init : function(component) {
    var action = component.get("c.getFormData");
    action.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var formDataMap = data.getReturnValue();
        component.set("v.supportedMetadataTypes", formDataMap.supportedMetadataTypes);
        component.set("v.instances", formDataMap.instances);
        component.set("v.runTimes", formDataMap.instanceRunTimes);
        component.set("v.availableUsers", formDataMap.availableUsers);
        component.set("v.scriptsLoaded", true);
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(action);
  },

  instancesInit : function(component) {
    if( component.get("v.scriptsLoaded") && !component.get("v.instancesInitialized")){
      window.BW.filter.init();
      this.addEventHandlers( component );

      var runTimes = component.get("v.runTimes") || {};
      var instances = component.get('v.instances').map(function(instanceName) {
        return {
          name: instanceName,
          lastRunTime: runTimes[instanceName] || 'NEVER'
        };
      });
      component.find("instances-multi-select").setInstances(instances);
      component.set("v.instancesInitialized", true);
    }
  },

  addEventHandlers : function( component, event ){
    var self = this;
    $('.search-btn').click(
          $A.getCallback(
            function () {
              BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Component Documentation', 'Search Components');
              self.doSearch(component);
            })
    );

    $('.page-block-panel-section .section-close-btn').click( function() {
      component.find("avail-users-combobox").clearFilterSelections();
    });
  },

  formKeyPress : function( component, evt ){
    var self = this;

    BW.AlmCommon.performActionOnEnter( $(self), evt, function() {
      BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Component Documentation', 'Search Components');
      self.doSearch(component);
      });
  },

  enableSearchButton : function(component) {
    component.set("v.disableSearch", false);
  },

  doSearch : function( component ){
    var $parent = $('.page-block-content-component-search');
    var searchParams = {};

    searchParams.name = $parent.find('.name').val() || null;
    searchParams.type = $parent.find('.ctype').val() || null;
    searchParams.parentComponent = $parent.find('.parent-name').val() || null;
    searchParams.selectedUsers = component.get('v.filterByUsers').map(function(user) {
      return user.value;
    });

    var selectedInstances = component.find("instances-multi-select").getSelectedInstanceNames() || [];

    var custEvt = $A.get("e.c:asyncSearchEvent");
    custEvt.setParams({"componentName": searchParams.name,
                     "componentType": searchParams.type,
                     "componentParentName": searchParams.parentComponent,
                     "selectedUsers": searchParams.selectedUsers,
                     "selectedInstances": selectedInstances.join()});

    custEvt.fire();
    component.set("v.disableSearch", true);
  },

  updateUserFilterLabel : function (component, helper) {
    var filterByUsersLength = component.get("v.filterByUsers").length;
    if (filterByUsersLength > 0) {
      component.set("v.filterByUsersLabel",
          filterByUsersLength + " value" + ((filterByUsersLength > 1) ? "s" : ""));
    } else {
      component.set("v.filterByUsersLabel", "Enter a value");
    }
      // "filter-applied" to page-block-pabnel-section-header
    helper.enableSearchButton(component);
  },

  suite: function($A) {
    return {
      setUp : function(cmp) {
      },
      tearDown : function(cmp) {
      },
      testItBlends : {
        test: function() {
          console.log(arguments);
        //  $A.test.assertEquals(3, self.itBlends(), 'It should blend');
        }
      }
    };
  }
})
