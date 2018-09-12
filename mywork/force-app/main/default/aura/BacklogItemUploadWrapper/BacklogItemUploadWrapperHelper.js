({
  init: function( component, event, helper ){
    var stepToComponent = component.get("v.stepComponentList");

    //Hide every step
    stepToComponent.forEach(function(domElementId, index) {
        var componentElement = component.find(domElementId);
        $A.util.addClass(componentElement, "slds-transition-hide inactive-slide");
    });
    component.set("v.step", 0);
  },
  handleStepChange: function( component, event, helper ){
    var newStepVal = event.getParam("value");
    var headerComponent = component.find("BacklogItemUploadHeader");

    if( newStepVal == 0 ){
      headerComponent.adjustNextAndPrevButtons();
    }

    window.setTimeout($A.getCallback(function() {
        if(component.isValid()) {
          if( newStepVal > 0 ){
            headerComponent.adjustNextAndPrevButtons();
          } else {
            // Reset mappingConfigData when brought back to first step.
            component.set("v.mappingConfigData", null);
          }
          var stepToComponent = component.get("v.stepComponentList");
          var oldStepVal = event.getParam("oldValue");
          var afterPageLoad = oldStepVal > -1;
          var previousClicked = newStepVal < oldStepVal;

          if( afterPageLoad ){
            helper.applyDelayedTransitonClasses( component, previousClicked, oldStepVal, newStepVal, stepToComponent );
          }
          else{
            $A.util.removeClass(component.find(stepToComponent[newStepVal]), "slds-transition-hide inactive-slide");
            $A.util.addClass(component.find(stepToComponent[newStepVal]), "slds-transition-show");
          }
        }
    }), component.get("v.fadeTimeout"));
  },
  applyDelayedTransitonClasses: function( component, previousClicked, oldStepVal, newStepVal, stepToComponent ){

    var oldComponentElement = component.find(stepToComponent[oldStepVal]);
    var newComponentElement = component.find(stepToComponent[newStepVal]);
    var oldStepClassToAdd = previousClicked ? 'slds-transition-hide' : 'slds-transition-hide-exit-left';
    var newStepClassToRemove  = previousClicked ? 'slds-transition-hide-exit-left' : 'slds-transition-hide';

    $A.util.removeClass(oldComponentElement, "slds-transition-show");
    $A.util.addClass(oldComponentElement, oldStepClassToAdd);

    window.setTimeout($A.getCallback(function() {
      if(component.isValid()){
        $A.util.removeClass(newComponentElement, newStepClassToRemove + " inactive-slide");
        $A.util.addClass(newComponentElement, "slds-transition-show");
        $A.util.addClass(oldComponentElement, "inactive-slide");
      }
      $('.upload-field-mapping-wrapper .alm-table thead').trigger('sticky_kit:detach');
      $('.upload-field-mapping-wrapper .alm-table thead').stick_in_parent(
          {
            offset_top:52,
            bottoming : false
          }
      );
      $('.upload-field-mapping-wrapper .alm-table thead').trigger('sticky_kit:recalc');
    }),500);
  },
  toggleNextButton : function(component, event) {
    var headerComponent = component.find("BacklogItemUploadHeader");
    headerComponent.toggleNextButton();
  }
})