({
  init : function(component) {
    var action = component.get("c.getVisualforceDomain");

    action.setCallback(this, function(data) {
      var options = {};

      options.successCb = function() {
        component.set('v.vfDomain', data.getReturnValue());
      };

      BW.LTCommon.auraCallbackHandler(data, options);
    });

    $A.enqueueAction(action);
  }

});