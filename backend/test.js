'use strict';

const assert = require('assert');
const { classify } = require('./server');

assert.match(classify('ohpm package not found').answer, /依赖诊断/);
assert.match(classify('ArkTS compile error').answer, /ArkTS/);
assert.match(classify('permission denied').answer, /权限诊断/);
assert.ok(classify('unknown').steps.length >= 3);
console.log('backend tests: 4 passed');
