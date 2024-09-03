const { Assertion, expect } = require('chai');
const { existsSync, mkdirSync, readFileSync, writeFileSync } = require('fs');
const { join } = require('path');

/**
 * @param {string} title 
 * @returns {string}
 */
const mask = title => title
    // .replace(/^\.\./, '')
    // .replace(/`/g, '')
    .replace(/^::/, '')
    .replace(/<(.*)>$/, '')
    .trim()
    .replace(/ /g, '-')
    // .replace(/[:^'()|]/g, '_')
    ;

const replacer = (_key, value) =>
    typeof value === 'bigint' ? { $bigint: value.toString() } : value;

const reviver = (_key, value) =>
    value !== null &&
        typeof value === 'object' &&
        '$bigint' in value &&
        typeof value.$bigint === 'string'
        ? BigInt(value.$bigint)
        : value;

const UPDATE_SNAPSHOTS = process.env['UPDATE_SNAPSHOTS'];

Assertion.addMethod('matchCall', function (/**@type{string}*/calldata, /**@type{unknown}*/decoded,/**@type{Mocha.Context}*/ctx) {
    const actual = this._obj;
    if (typeof actual !== 'string') throw new TypeError('Actual value should be a string');
    if (ctx.test === undefined) throw new TypeError('Mocha context is not defined');

    const [root, ...titles] = ctx.test.titlePath().map(mask);

    const snapshotDir = join('test', '__snapshots__');
    mkdirSync(snapshotDir, { recursive: true });

    const snapshotFile = join(snapshotDir, `${root}.snap.json`);

    const json = JSON.parse(
        existsSync(snapshotFile) ? readFileSync(snapshotFile, 'utf8') : '{}',
        reviver);

    const getExpectObj = () => {
        let obj = json;
        for (const level of titles) {
            if (obj[level] === undefined) {
                obj[level] = {};
            }
            obj = obj[level];
        }
        return obj;
    }

    const expectObj = getExpectObj();
    if (UPDATE_SNAPSHOTS) {
        ctx.test.title += ` 📸`;
        expectObj['__calldata'] = calldata;
        expectObj['__expect'] = actual;
        expectObj['__decoded'] = decoded;
    } else {
        ctx.test.title += ` 🎞️`;
        expect(expectObj['__expect'], `${snapshotFile}`).to.be.equal(actual);
    }

    const out = JSON.stringify(json, replacer, 4);
    writeFileSync(snapshotFile, out);
});
