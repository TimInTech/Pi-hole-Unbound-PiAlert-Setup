const assert = require('assert');
const nodes = new Map();
function element(id) {
    if (!nodes.has(id)) nodes.set(id, { className: '', textContent: '', classList: {add(){}, remove(){}}, addEventListener(){}, focus(){} });
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
global.sessionStorage = {getItem: () => 'key'};
global.fetch = async url => ({ok: true, json: async () => data[url]});
global.setTimeout = () => {};
require('../dashboard/app.js');
setImmediate(() => {
    assert.strictEqual(element('overall-status .status-indicator').className, 'status-indicator healthy');
    assert.strictEqual(element('overall-status .status-text').textContent, 'Alle Kernsysteme gesund');
});
