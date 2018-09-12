({
  init : function(component, event, helper) {
    var options = {
      parent: $('#alm-container'),
      bottoming : false
    },
    $banner = $('.banner-wrap');
    if ($banner.length && options.parent.length) {
      $banner.stick_in_parent( options );
    }
  }
})
