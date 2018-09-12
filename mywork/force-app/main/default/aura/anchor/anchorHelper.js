({
  doPopulateVisualForceURLNamespace : function(component) {
    var action = component.get("c.getNamespace"),
    url = component.get("v.value");

    action.setCallback(this, function(data) {
      if (data.getState() === "SUCCESS") {
        var namespace = data.getReturnValue();
        if (namespace) {
          url = url.replace("/apex/", "/apex/" + namespace + "__");
          component.set("v.value", url);
        }
      }
      
    });
    $A.enqueueAction(action);
  }
})