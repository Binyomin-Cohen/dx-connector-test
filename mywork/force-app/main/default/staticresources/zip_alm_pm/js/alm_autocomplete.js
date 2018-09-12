/*
 * jQuery UI custom autocomplete for ALM
 *
 * Depends:
 *   - jQuery UI Autocomplete widget
 *
*/
(function(global) {
    var init = function($) {
        $.widget('custom.almautocomplete', $.ui.autocomplete, {
            _renderItem: function(ul, item) {
                var searchText = this.element.val(),
                  displayText;

                //highlight matching text
                displayText = item.label.replace(  new RegExp( '(' + $.ui.autocomplete.escapeRegex( searchText ) + ')(?![^<]*>)', "i" ), '<span class="matching-text">$1</span>');
                return $( "<li>" )
                    .attr( "data-value", item.value )
                    .append( $( "<a>" + displayText + "</a>" ))
                    .appendTo( ul );
            }
        });
    };

    if(typeof define !== 'undefined') {
        define(['jquery', 'jquery-ui'], function(jQuery) {
            init(jQuery);
        });
    } else {
        init(global.jQuery);
    }
})(this);
