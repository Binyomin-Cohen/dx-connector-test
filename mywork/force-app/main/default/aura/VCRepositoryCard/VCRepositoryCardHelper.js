({
  navigateToRepoEdit : function(component) {
      var url = "/apex/AdminVersionControl?id="+component.get('v.vcRepository').id;
      BW.AlmCommon.navigateTo(BW.LTCommon.buildNamespaceFriendlyUrl(url, component.get('v.namespace')));
  }
});