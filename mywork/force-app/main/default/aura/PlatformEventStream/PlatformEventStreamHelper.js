({
  getConfig: function(component, cbFn) {
    var action = component.get("c.getConfig");
    action.setCallback(this, function(data) {
      var options = {};
      options.successCb = function() {
        var config = data.getReturnValue();
        component.set('v.sessionId', config.sessionId);
        if (component.get('v.namespace') === undefined || component.get('v.namespace') === null) { // respect namespace override
          component.set('v.namespace', config.namespace);
        }
        cbFn(null, config);
      };
      options.errorCb = function(err) {
        cbFn(err, null);
      }
      BW.LTCommon.auraCallbackHandler(data, options);
    });
    $A.enqueueAction(action);
  },

  initCometDStream: function(component, cbFn) {
    var sessionId = component.get('v.sessionId');

    var cometd = new org.cometd.CometD();
    if (!cometd) { throw "CometD is not defined! Can not stream Platform Events"; }

    cometd.configure({
      url: window.location.protocol + '//' + window.location.hostname + '/cometd/42.0/',
      requestHeaders: { Authorization: 'OAuth ' + sessionId},
      appendMessageTypeToURL : false
    });
    cometd.websocketEnabled = false; // Currently Lightning/LockerService does not work with websockets...
    component.set('v.cometd', cometd);

    cometd.handshake(function(handshakeReply) {
      if (handshakeReply.successful) {
        component.set("v.cometdInited", true);
        cbFn();
      } else {
        throw 'Failed to connected to CometD.';
      }
    });
  },

  addEventSubscription: function(component, helper, platformEventName) {
    var subscriptions = component.get('v.cometdSubscriptions'),
        cometd = component.get('v.cometd');

    var eventPath = '/event/' + this.namespaceQualify(platformEventName, component.get('v.namespace'));

    var platformEventHandler = $A.getCallback(function(platformEventData) {
      var evt = $A.get('e.c:PlatformEventStreamUpdate');
      var returnData = component.get('v.handleNamespacing') ?
                          helper.removeNamespaceFromMapKeys(platformEventData.data.payload, component) :
                          platformEventData.data.payload;
      evt.setParams({eventType: platformEventName, data: returnData});
      evt.fire();
    });

    var newSubscription = cometd.subscribe(eventPath, platformEventHandler, function(errors, data) {
      subscriptions.push(newSubscription);
      component.set('v.cometdSubscriptions', subscriptions);
    });
  },

  namespaceQualify: function(name, namespace) {
    return name.startsWith(namespace) ? name : namespace + name;
  },

  removeNamespace: function(name, namespace) {
    return name.startsWith(namespace) ? name.slice(namespace.length) : name;
  },

  removeNamespaceFromMapKeys: function(m, component) {
    var namespace = component.get('v.namespace');
    if (namespace === undefined || namespace === null ) {throw 'Namespace not yet defined!'}

    var newMap = {},
        keys = Object.keys(m),
        key;
    for (var i = 0; i < keys.length; i++) {
      key = keys[i];
      newMap[this.removeNamespace(key, namespace)] = m[key];
    }
    return newMap;
  },
})
