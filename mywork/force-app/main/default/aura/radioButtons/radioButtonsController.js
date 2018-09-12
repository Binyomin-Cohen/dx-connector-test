({
  handleRadioButtonsValueChange : function(component, event){
    var radioButtonVal = event.target.value;
    component.set("v.radioButtonsSelectedValue", radioButtonVal);
  }
})
