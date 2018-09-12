({
  scrollToSearchForm : function() {
    var bodyTop = $('body').scrollTop(),
     htmlTop = $('html').scrollTop(),
     $searchFormParent = $('#alm-container');

    //call animate on both html and body to work cross browser
    $('html, body').animate({
      scrollTop: $searchFormParent.offset().top - 1
    }, function() {
      //fall back for FF scroll animation not working in lightning
      if (bodyTop === $('body').scrollTop()
        && htmlTop === $('html').scrollTop()) {
        $searchFormParent.get(0).scrollIntoView();
      }
    });
  }
})