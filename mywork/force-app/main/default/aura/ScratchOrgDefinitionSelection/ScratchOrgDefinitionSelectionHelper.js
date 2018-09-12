({
  init : function(component) {
    var getScratchOrgDefs = component.get('c.getScratchOrgDefinitions');
    getScratchOrgDefs.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var scratchOrgDefs = data.getReturnValue();
        component.set('v.definitionOptions', scratchOrgDefs.map(function(option) {
          return {
            "label" : option.Name,
            "value" : option.Id
          };
        }));
      };
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(getScratchOrgDefs);
  },

  setTemplateLinkUrl : function(component, scratchDefId) {
    var navService = component.find("nav-service");
      
    var pageReference = {
      "type" : "standard__recordPage",
      "attributes" : {
        "recordId" : scratchDefId,
        "actionName" : 'view'
      }
    };
      
    var defaultUrl = "/"+ scratchDefId;
    navService.generateUrl(pageReference)
      .then($A.getCallback(function(url) {
        component.set("v.templateLinkUrl", url ? url : defaultUrl);
      }), $A.getCallback(function(error) {
        component.set("v.templateLinkUrl", defaultUrl);
      }));
  }

})
