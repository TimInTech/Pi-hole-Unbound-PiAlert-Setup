const fs = require('fs');
const vm = require('vm');
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
vm.runInNewContext(fs.readFileSync('dashboard/app.js', 'utf8'), {
    document, sessionStorage: {getItem: () => 'key'},
    fetch: async url => ({ok: true, json: async () => data[url]}),
    setTimeout() {}, console, Date
});
setImmediate(() => {
    assert.strictEqual(element('overall-status .status-indicator').className, 'status-indicator healthy');
    assert.strictEqual(element('overall-status .status-text').textContent, 'Alle Kernsysteme gesund');
});
