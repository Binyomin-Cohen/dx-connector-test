// Put all requirejs setup here
require.config({
  baseUrl: baseRequireURL,
  // In paths, specify additional directories that should be exposed
  paths: {
    templates: '../templates',
    external: '../external',
    cometd: '../external/cometd',
    jquery: '../external/jquery/jquery',
    'jquery-ui': '../external/jquery/jquery-ui',
    'jquery-blockUI': '../external/jquery/jquery.block-ui',
    'jquery-tablesorter': '../external/jquery/jquery.tablesorter',
    'jquery-datatable': '../external/datatable/datatable',
    'sfquery': '../external/sf-query/sfquery',
    moment: '../external/moment/moment',
    'aljs-init': '../external/aljs-datepicker/jquery.aljs-init',
    'aljs-datepicker': '../external/aljs-datepicker/jquery.aljs-datepicker'
  },
  shim: {
    'external/bootstrap.min': {
      deps: ['jquery'],
      exports: '$'
    },
    'external/bootstrap_multiselect': {
      deps: ['jquery'],
      exports: '$'
    },
    'cometd/cometd': {
      exports: 'org.cometd'
    },
    'cometd/jquery_cometd': {
      deps: ['cometd/cometd', 'cometd/json2', 'jquery'],
      exports: '$'
    },
    'cometd/json2': {
      exports: 'JSON'
    },
    'external/jquery.sticky-kit': {
      deps: ['jquery'],
      exports: '$'
    },
    'external/jquery.stickytableheaders.min': {
       deps: ['jquery'],
       exports: '$'
    },
    'jquery-tablesorter': {
      deps: ['jquery'],
      exports: '$'
    },
    'jquery-datatable': {
      deps: ['jquery'],
      exports: '$'
    },
    'sfquery': {
      deps: ['jquery'],
      exports: '$'
    }
  }
});