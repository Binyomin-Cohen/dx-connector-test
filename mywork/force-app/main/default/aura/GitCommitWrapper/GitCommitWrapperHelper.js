({
    init : function(component) {
      var commitRequest = component.get("v.commitRequest") || {};
      component.set("v.commitRequest", {
        backlogItemId: component.get("v.recordId"),
        backlogComponentIds: commitRequest.backlogComponentIds || [],
        repositoryId: commitRequest.repositoryId || "",
        branchName: commitRequest.branchName || "",
        commitMessage: commitRequest.commitMessage || "",
        instanceId: commitRequest.instanceId || ""
      });

      var loadPageStateAction = component.get('c.loadPageState');
      loadPageStateAction.setParams({
        "backlogItemId" : component.get('v.recordId')
      });
      loadPageStateAction.setCallback(this, function(data) {
        var options = {
          successCb : function() {
            if (data) {
              component.set('v.state', data.getReturnValue());
            }
          },
          errorCb : function(message) {
            BW.LTCommon.addPageMessage('error', message);
          }
        };
        BW.LTCommon.auraCallbackHandler(data, options);
      });
      $A.enqueueAction(loadPageStateAction);

      var expirePageStateAction = component.get('c.expirePageState');
      expirePageStateAction.setParams({
        "backlogItemId" : component.get('v.recordId')
      });
      $A.enqueueAction(expirePageStateAction);

      var action = component.get('c.getInstances');
      action.setCallback(this, function(data) {
        var options = {};
        options.successCb = function() {
          var instances = data.getReturnValue();

           component.set('v.instances', instances.map(function(instance) {
             return {
               "label" : instance.Name,
               "value" : instance.Id
             };
           }));
        };
        BW.LTCommon.auraCallbackHandler(data, options);

        var state = component.get('v.state');

        if (BW.AlmCommon.getProperty(state, 'selectedInstanceId')) {
          component.find('instance-select').setValue(state.selectedInstanceId);
        }
      });

      $A.enqueueAction(action);

      $('.banner-wrap').stick_in_parent({
        parent: $('#alm-container'),
        bottoming : false
      });

      BW.AlmCommon.addBeforeUnloadEventListener();
    },

  selectInstance : function(component, instanceId) {
    component.set('v.selectedInstanceId', instanceId);
    component.set('v.isAuthorized', false);

    var commitRequest = component.get("v.commitRequest");
    commitRequest.instanceId = instanceId;
    component.set("v.commitRequest", commitRequest);

    var evt = component.getEvent("unsavedPageEvent");
    evt.setParam("isPageUpdated", true);
    evt.fire();
  }
});
