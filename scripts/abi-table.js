#!/usr/bin/env node

// SPDX-License-Identifier: Apache-2.0

const { readFileSync } = require('fs');
const { Fragment } = require('ethers');

/**
 * @param {string} kind
 * @param {unknown[]} abi
 * @param {{[sighash: string]: {notice: string}}} userdoc
 * @param {{[sighash: string]: {details: string}}} devdoc
 */
function* data(kind, abi, userdoc, devdoc) {
    for (const entry of abi) {
        const frag = Fragment.from(entry);
        if (frag.type === kind) {
            const sighash = frag.format('sighash');
            const [member] = frag.format('full').replace(`${kind} `, '').split(' returns ');
            const notice = (userdoc[sighash]?.notice ?? '').trim();
            const dev = (devdoc[sighash]?.details ?? '').trim();

            yield { member, notice, dev };
        }
    }
}

function main() {
    const jsonPaths = process.argv.slice(2);
    if (jsonPaths.length === 0) throw new Error('Invalid json path(s) to extract ABI from');

    const { abi, userdoc, devdoc } = jsonPaths
        .map(jsonPath => JSON.parse(readFileSync(jsonPath, 'utf8')))
        .reduce(
            ({ abi, userdoc, devdoc }, json) => ({
                abi: [...json.abi, ...abi],
                userdoc: { ...json.userdoc, ...userdoc },
                devdoc: { ...json.devdoc, ...devdoc },
            }),
            { abi: [], userdoc: {}, devdoc: {} }
        );

    const write = console.info;
    [
        ['Function', 'methods'],
        ['Event', 'events'],
    ].forEach(([kind, prop]) => {
        const members = [...data(kind.toLowerCase(), abi, userdoc ?? {}, devdoc ?? {})];
        if (members.length > 0) {
            write();
            write(`| ${kind} | Comment |`);
            write('|----------|---------|');
            for (const { member, notice, dev } of members) {
                const sep = notice !== '' && dev !== '' && !notice.endsWith('.') ? '.' : '';
                write(`| \`${member}\` | ${notice}${sep} ${dev} |`);
            }
        }
    });
}

main();
