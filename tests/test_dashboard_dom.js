const assert = require('assert');
const nodes = new Map();
function element(id) {
    if (!nodes.has(id)) nodes.set(id, { className: '', textContent: '', focused: false, classList: {add(){}, remove(){}}, addEventListener(){}, focus(){this.focused = true;} });
    return nodes.get(id);
}
const data = {
    '/health': {uptime_seconds: 10, version: '1'},
    '/urls': {host_ip: '127.0.0.1'},
    '/pihole': {ftl_active: true, upstreams: ['127.0.0.1#5335']},
    '/unbound': {port: 5335, service_active: true, dig_ok: true},
    '/netalertx': {}, '/stats': {}
};
const document = {
    addEventListener(name, fn) { if (name === 'DOMContentLoaded') fn(); },
    getElementById(id) { return id.includes(' ') ? null : element(id); },
    querySelector(selector) { return element(selector.slice(1)); }
};
global.document = document;
let removedSessionKey = false;
global.sessionStorage = {removeItem(key) { if (key === 'suite_api_key') removedSessionKey = true; }};
global.fetch = async url => ({ok: true, json: async () => data[url]});
global.setTimeout = () => {};
require('../dashboard/app.js');
setImmediate(() => {
    assert.strictEqual(removedSessionKey, true);
    assert.strictEqual(element('api-key').focused, true);
});
