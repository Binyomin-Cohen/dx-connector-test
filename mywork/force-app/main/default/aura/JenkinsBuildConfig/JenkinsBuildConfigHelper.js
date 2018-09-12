({
  addPageMessage : function(type, message) {
    var pageMessageAddEvent = $A.get('e.c:pageMessageAdd');
    pageMessageAddEvent.setParams({
      'type' : type,
      'message' : message
    });
    pageMessageAddEvent.fire();
  },

  addCriteria : function(component, newCriteria) {
    var saveBuildRuleAction = component.get("c.saveBuildRule");
    saveBuildRuleAction.setParams({
      jenkinsJobId : component.get("v.jenkinsJobId"),
      newCriteria : newCriteria
    });

    var self = this;

    saveBuildRuleAction.setCallback(this, function(data) {
      var options = {};

      options.errorCb = function(errorMessage) {
        self.addPageMessage("error", errorMessage);
        //reset the combobox to the saved state
        self.populateAvailableOptions(component);
      };

      options.cb = function() {
        BW.LTCommon.fireGoogleAnalyticsTrackingEvent(
            'Jenkins Integration', 'Add Rule to Jenkins Job');
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(saveBuildRuleAction);
  },

  deleteCriteria : function(component, deletedCriteria) {
    var removeFromBuildRuleAction = component.get("c.removeFromBuildRule");
    removeFromBuildRuleAction.setParams({
      jenkinsJobId : component.get("v.jenkinsJobId"),
      deletedCriteria : deletedCriteria
    });

    var self = this;

    removeFromBuildRuleAction.setCallback(this, function(data) {
      var options = {};

      options.errorCb = function(errorMessage) {
        self.addPageMessage("error", errorMessage);
        //reset the combobox to the saved state
        self.populateAvailableOptions(component);
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(removeFromBuildRuleAction);
  },

  populateAvailableOptions : function(component) {
    var getAvailableOptionsAction = component.get("c.getAvailableOptions");
  
    getAvailableOptionsAction.setParams({
       jenkinsJobId : component.get("v.jenkinsJobId")
    });

    var self = this;

    getAvailableOptionsAction.setCallback(this, function(data) {
      var options = {};      
      options.successCb = function() {
        var optionsData = data.getReturnValue();

        component.set('v.availableOptions', optionsData.map(function(option) {
          return {
            label : option.label + ' (' + option.value + ')',
            value : option.value,
            isSelected : option.isSelected
          }
        }));
        component.set('v.selectedOptions', component.get('v.availableOptions').filter(function(option) {
          return option.isSelected;
        }));
      };

      options.errorCb = function(errorMessage) {
        self.addPageMessage("error", errorMessage);
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(getAvailableOptionsAction);
  }

})