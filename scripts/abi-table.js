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
 * @param {string} jsonPath
 */
function* table(jsonPath) {
    const json = JSON.parse(readFileSync(jsonPath, 'utf8'));
    const {
        abi,
        methodIdentifiers,
        metadata: {
            output: { devdoc, userdoc },
        },
    } = json;

    for (const member of abi) {
        const frag = Fragment.from(member);
        const sighash = frag.format('sighash');
        const selector = methodIdentifiers[sighash];
        const [fn, returns] = frag.format('full').split(' returns ');
        const notice = userdoc.methods[sighash]?.notice;
        const dev = devdoc.methods[sighash]?.details;

        yield { fn, returns, selector, notice, dev };
    }
}

function main() {
    const write = console.info;

    const jsonPath = process.argv[2];

    write('| Function | Returns | Selector | Behavior |');
    write('|----------|---------|----------|----------|');
    for (const { fn, returns, selector, notice, dev } of table(jsonPath)) {
        write(
            `| \`${fn}\` | \`${returns.slice(0, 100)}\` | \`${selector}\` | ${notice ?? ''} ${dev ?? ''} |`
        );
    }
}

main();
