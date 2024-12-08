#!/usr/bin/env node

/*-
 * Hedera Hardhat Forking Plugin
 *
 * Copyright (C) 2024 Hedera Hashgraph, LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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
            const notice = userdoc[sighash]?.notice;
            const dev = devdoc[sighash]?.details;

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
        const members = [...data(kind.toLowerCase(), abi, userdoc[prop] ?? {}, devdoc[prop] ?? {})];
        if (members.length > 0) {
            write();
            write(`| ${kind} | Comment |`);
            write('|----------|---------|');
            for (const { member, notice, dev } of members) {
                write(`| \`${member}\` | ${notice ?? ''} ${dev ?? ''} |`);
            }
        }
    });
}

main();
