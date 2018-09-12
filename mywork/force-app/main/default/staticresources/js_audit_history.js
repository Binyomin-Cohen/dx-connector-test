jQuery(document).ready(function($) {
    $('table.alm-table').tablesorter({
        widgets: ['zebra'],
        widgetOptions: {
            zebra: ['row-b', 'row-a']
        },
        emptyTo: 'bottom',
        cssAsc: 'asc',
        cssDesc: 'desc',
        cssNone: 'unsorted'
    })
});
