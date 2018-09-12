// This RequireJS plugin allows for other modules to specify optional dependencies.
// By requiring your dependency using the syntax "try!<module>" and specifying a dummy
// definition for it below, you can avoid module load failures resulting from failing dependencies.

define({
    load: function(name, parentRequire, onload, config) {
        parentRequire([name], onload, function(error) {
            // Dummy module definitions.
            // Any member that may be referenced by a dependent module should be declared here.
            var dummyModules = {
                analytics : {
                    trackEvent : function() {}
                }
            };

            // Defines a dummy module for each failing dependency before retrying the require.
            error.requireModules.forEach(function(moduleName) {
                requirejs.undef(moduleName);
                define(moduleName, [], function() { return dummyModules[moduleName] || null; });
            });
            parentRequire(error.requireModules);
        });
    }
});