({

  init : function(component, event, helper) {
    var recordId = component.get('v.recordId');
    if ($A.util.isEmpty(recordId)) {
      //List View Mode
      this.refreshRepoBlocks(component);
      component.set('v.editMode', false);
    } else if (recordId === 'new') {
      //Create new record mode
      var newRepoAndJob = this.initNewRepoAndJob();
      component.set('v.selectedRepo',newRepoAndJob);
      this.getRepositoryHosts(component);
      component.set('v.editMode', true);
    } else {
      //Edit existing repo mode
      this.getExistingRepo(component, recordId);
    }
    this.getSourceFormatOptions(component);
  },
  
  getSourceFormatOptions: function(component) {
   var action = component.get('c.getSourceFormatOptions');
    action.setCallback(this, function(data) {
      var options = {};
      action.setParams({});
      options.successCb = function() {
        component.set('v.sourceFormatOptions', data.getReturnValue());
      };

      options.errorCb = function(error) {
        BW.LTCommon.addPageMessage("error", error);
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(action);
  },

  getExistingRepo : function(component, recordId) {
    var self = this;
    var action = component.get('c.getExistingRepository');
    
    var params = {
        repoId: recordId
      };

    action.setParams(params);
    action.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var existingRepo = data.getReturnValue();
        if ($A.util.isEmpty(existingRepo.job)) {
          existingRepo.job = self.initNewJob();
          component.set('v.selectedRepo.job', {});
          component.set('v.hasActiveJob', false);
        } else {
          component.set('v.hasActiveJob', true);
        }
        if ($A.util.isUndefinedOrNull(existingRepo.host)) {
          //default host to blank, so that the data-attribute can appear in the markup
          existingRepo.host = '';
        }
        component.set('v.selectedRepo',existingRepo);
        self.getRepositoryHosts(component, existingRepo.host);
        component.set('v.editMode', true); 
      };

      options.errorCb = function(error) {
        BW.LTCommon.addPageMessage("error", error);
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(action);
  },

  refreshRepoBlocks : function(component) {
    var self = this;
    var action = component.get('c.getExistingRepositories');
    action.setCallback(this, function(data) {
      var options = {};
      
      options.successCb = function() {
        var recordId = component.get('v.recordId');
        var existingRepos = data.getReturnValue().map(function(repo) {
          return repo;
        });
        component.set('v.vcRepositories', existingRepos);
      };
      
      options.errorCb = function(error) {
        BW.LTCommon.addPageMessage("error", error);
      };
      
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    
    $A.enqueueAction(action);
  },

  getRepositoryHosts : function(component, selectedHost) {
    var action = component.get("c.getRepositoryHosts");
    action.setCallback(this, function(data) {
      var options = {};

      options.successCb = function() {
        var hostPicklist = [{
            apiName : "",
            label : component.get("v.defaultHostPlaceholder"),
            selected : ''
        }];
        var hostResults = data.getReturnValue();
        Object.keys(hostResults).forEach(function(apiName) {
          var selectedAttribute = apiName == selectedHost ? 'selected' : '';
          hostPicklist.push({
            apiName : apiName,
            label: hostResults[apiName],
            selected: selectedAttribute
          });
        });
        component.set("v.hosts", hostPicklist);
      };

      options.errorCb = function(error) {
        BW.LTCommon.addPageMessage("error", error);
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(action);
  },
  
  getDayValuesFromHiddenInputs : function(job) {
    var booleanType = true;
    this.getValueFromHiddenInput(job,'day-property', booleanType);
  },

  getIntervalFromHiddenInputs : function(job) {
    this.getValueFromHiddenInput(job,'interval-property');
  },

  getEmailFromHiddenInput : function(job) {
    this.getValueFromHiddenInput(job,'email-input');
  },

  getStatusFromHiddenInput : function(job) {
    this.getValueFromHiddenInput(job,'status-property');
  },

  getValueFromHiddenInput : function(job, className, booleanType) {
    booleanType = $A.util.isEmpty(booleanType) ? false : booleanType;
    $( "input."+className ).each(function() {
      var value = booleanType ? $( this ).val() === "true" : $( this ).val();
      job[$( this ).attr('id')] = value;
    });
  },

  setUnsavedChanges : function(component, event) {
    if ( this.allRequiredFieldsPopulated(component) ) {
      BW.adminRepos.setUnsavedChanges();
    } else {
      BW.adminRepos.resetUnsavedChanges();
    }
  },

  upsertRepository : function(component) {
    var syncActivated = $(".is-tool-activated").prop("checked");
    var job = component.get('v.selectedRepo.job') === undefined ? {} : component.get('v.selectedRepo.job');
    var destroyJob = false;
    if( syncActivated ) {
      var syncDate = component.get('v.selectedRepo.syncDate');
      if ($A.util.isEmpty(syncDate)) {
        BW.LTCommon.addPageMessage("error", 'Please enter the Sync Date' );
        return;
      } else if(!this.validateSyncDate(syncDate)){
        BW.LTCommon.addPageMessage("error", 'Please enter the Sync Date in the following format : YYYY-MM-DD');
        return;
      }
      if ($('#initial-schedule-state').val() === 'false') {
        BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Version Control', 'Schedule Commit Sync');
      }
      this.getDayValuesFromHiddenInputs(job);
      this.getIntervalFromHiddenInputs(job);
      this.getEmailFromHiddenInput(job);
      this.getStatusFromHiddenInput(job);
      component.set('v.selectedRepo.job', job);
    } else {
      destroyJob = true;
    }
    
    var repo = component.get('v.selectedRepo');
    //If the sync date is cleared out, the inputdate field makes it an empty string
    if (repo.syncDate === ''){
      repo.syncDate = null;
    }
    
    repo.enableExternalCommitLink = $A.util.getBooleanValue(repo.enableExternalCommitLink);
    repo.sourceFormat = component.get('v.sourceFormat');
    var self = this,
    action = component.get('c.upsertRepositoryWithALMJob'),
    params = {
      repoRepresentation: JSON.stringify(repo),
      destroyJob: destroyJob
    };
    
    action.setParams(params);

    action.setCallback(this, function(data) {
      var options = {};

      options.successCb = function() {
        var isNew = $A.util.isEmpty(component.get('v.selectedRepo').id);
        var eventName = 'Edit_Repo';
        var successMessage = "Updated the repository: ";
        var successRepo = data.getReturnValue();
        
        BW.adminRepos.resetUnsavedChanges();
        if (isNew) {
          BW.LTCommon.fireGoogleAnalyticsTrackingEvent('Version Control', 'Add Repository');
          var url = BW.LTCommon.buildNamespaceFriendlyUrl("/apex/AdminVersionControl", component.get('v.namespace'));
          BW.AlmCommon.navigateTo(url);
        } else {
          BW.LTCommon.fireGoogleAnalyticsTrackingEvent('VC', eventName, 'VC-' + eventName);
          BW.LTCommon.addPageMessage("success", successMessage + successRepo.name );
          var hasActiveJob = !$A.util.isEmpty(successRepo.job);
          if ( !hasActiveJob ) {
            component.set('v.selectedRepo.job', {});
            successRepo.job = self.initNewJob();
          }
          component.set('v.selectedRepo',successRepo);
          component.set('v.hasActiveJob', hasActiveJob);
        }
      };

      options.errorCb = function(error) {
        var isNew = $A.util.isEmpty(component.get('v.selectedRepo').id);
        var failureMessage = isNew ? "Failed to create a new repository: " : "Failed to update repository: ";
        BW.LTCommon.addPageMessage("error", failureMessage + error );
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(action);
  },

  clearPageMessages : function() {
    $A.get('e.c:pageMessagesClear').fire();
  },
  
  initNewJob : function() {
    moment.tz.setDefault($A.get("$Locale.timezone"));
    var defaultStartTime = moment({h:9, m:0 }).valueOf();
    var defaultEndTime = moment({h:21, m:0 }).valueOf();

    var newJob = {
        "interval" : 0,
        "scheduledOnMonday" : true,
        "scheduledOnTuesday" : true,
        "scheduledOnWednesday" : true,
        "scheduledOnThursday" : true,
        "scheduledOnFriday" : true,
        "scheduledOnSaturday" : false,
        "scheduledOnSunday" : false,
        "status" : "Scheduled",
        "scheduledStartTime" : defaultStartTime,
        "scheduledEndTime" : defaultEndTime
        };
    
    return newJob;
  },

  validateSyncDate : function(syncDateToValidate) {    
    var dateFormat = 'YYYY-MM-DD';
    return moment(syncDateToValidate, dateFormat, true).isValid();
  },

  initNewRepoAndJob : function() {
    var repoWithJob = { 
      "host" : "",
      "metadataPath" : "src",
      "job" : this.initNewJob()
    };
    return repoWithJob;
  },
  
  allRequiredFieldsPopulated : function (component) {
    var repo = component.get('v.selectedRepo'),
        required = ['name', 'repositoryUrl'],
        extCommitFields = ['host', 'orgName'],
        requiredFields = $A.util.getBooleanValue(repo.enableExternalCommitLink) ? required.concat(extCommitFields) : required;

    for (var i = 0; i < requiredFields.length; i++) {
      if ($A.util.isEmpty(repo[requiredFields[i]])) {
        return false;
      }
    }
    return true;
  },

  updateSourceFormat: function(component, event, helper) {
    var selectedFormat = component.find("sourceFormatOptions").get("v.value");
    component.set('v.sourceFormat', selectedFormat);
    helper.setUnsavedChanges(component, event);
  },

});
