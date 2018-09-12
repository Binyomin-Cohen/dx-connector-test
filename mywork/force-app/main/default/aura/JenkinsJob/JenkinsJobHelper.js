({
  init : function(component) {
    this.getSuccessfulBuildsPickListOptions(component);
    this.getBuildRuleCriteria(component);
  },

  startJenkinsJob : function(component) {
    var createBuildAction = component.get("c.createJenkinsBuild");
    var previousBuildId = component.get("v.selectedPreviousBuildId");
    createBuildAction.setParams({
      "jenkinsJobId" : component.get('v.jenkinsJobId'),
      "previousSuccessfulBuildId" : previousBuildId
    });

    var self = this;

    createBuildAction.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var buildId = data.getReturnValue();
        self.finishJobStart(component, buildId);
      };

      options.errorCb = function(errorMessage) {
        self.clearPageMessages();
        BW.LTCommon.addPageMessage("error", errorMessage);
        component.set("v.jobInProgress" , false);
      };

      options.cb = function() {
        if ($A.util.isEmpty(previousBuildId)) {
          BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Jenkins Integration', 'Jenkins Job Started');
        } else {
          BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Jenkins Integration', 'Jenkins Job Started', 'Jenkins Integration - Job Started with Build Selected');
        }
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(createBuildAction);
  },

  finishJobStart : function(component, buildId) {
    var startJobAction = component.get("c.startJob");
    startJobAction.setParams({
      "buildId" : buildId
    });

    var self = this;

    startJobAction.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var pageMessage = data.getReturnValue();
        BW.LTCommon.addPageMessage(pageMessage.messageType, pageMessage.message);
      };

      options.errorCb = function(errorMessage) {
        BW.LTCommon.addPageMessage("error", errorMessage);
      };

      options.cb = function() {
        component.set("v.jobInProgress" , false);
        self.clearPageMessages();
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(startJobAction);
  },

  getBuildRuleCriteria : function(component) {
    var action = component.get('c.getBuildRuleCriteria'),
        self = this;

    action.setParams({
      jenkinsJobId : component.get("v.jenkinsJobId")
    });

    action.setCallback(this, function(data) {
      var options = {};

      options.successCb = function() {
        var buildRuleCriteria = data.getReturnValue();
        var isBuildRuleSatisfied = true;
        component.set("v.buildRuleCriteria", buildRuleCriteria);
        component.set("v.isBuildRuleSatisfied", buildRuleCriteria.reduce(function(accumulator, rule) {
          return accumulator && rule.value;
        }, true) );
      };

      options.errorCb = function(error) {
        self.clearPageMessages();
        BW.LTCommon.addPageMessage("error", error);
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(action);
  },

  getSuccessfulBuildsPickListOptions : function(component) {
    var action = component.get('c.getExistingSuccessfulBuildsForRelease');
    var self = this;

    action.setParams({
      releaseId : component.get("v.releaseId")
    });

    action.setCallback(this, function(data) {
      var options = {};

      options.successCb = function() {
        var pickListValues = data.getReturnValue().map(function(build) {
          return {
            "label" : build.ciInstanceName + " " + build.jobName + " " + build.name,
            "value" : build.id
          };
        });
        component.set("v.successfulBuildPickListOptions", pickListValues);
      };

      options.errorCb = function(error) {
        self.clearPageMessages();
        BW.LTCommon.addPageMessage("error", error);
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(action);
  },

  comboboxChange : function(component, event) {
    component.set("v.selectedPreviousBuildId", event.getParam("newValue"));
    BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Jenkins', 'Job', 'Build Selected');
  },

  clearPageMessages : function() {
    $A.get('e.c:pageMessagesClear').fire();
  }

});