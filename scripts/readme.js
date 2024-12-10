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

const { strict: assert } = require('assert');
const { readFileSync, writeFileSync } = require('fs');
const path = require('path');
const c = require('ansi-colors');
const { execSync } = require('child_process');

function main() {
    const license = readFileSync(
        path.join(__dirname, '..', 'resources', 'license.js.header'),
        'utf8'
    );

    const MARKERS = /**@type{const}*/ ([
        { begin: /^```\w+ (.+)$/, end: '```' },
        { begin: /^<!-- (.+) -->$/, end: '<!-- -->' },
    ]);

    const args = process.argv.slice(2);
    if (args.length !== 1) throw new Error('Invalid number of arguments');
    const readme = readFileSync(args[0], 'utf8');

    /** @type {{line: string, file: string, end: typeof MARKERS[number]['end']} | null} */
    let marker = null;
    let output = '';
    const write = (/** @type string */ line) => (output += line + '\n');

    for (const line of readme.split('\n')) {
        const trimmedLine = line.trimEnd();
        const found = MARKERS.map(marker => ({
            ...marker,
            match: trimmedLine.match(marker.begin),
        })).find(({ match }) => match !== null);
        if (found !== undefined && marker === null) {
            assert(found.match !== null);
            marker = { line: trimmedLine, file: found.match[1], end: found.end };
            process.stdout.write(`Opening marker ${c.magenta(marker.file)} .. `);
        } else if (marker !== null && trimmedLine === marker.end) {
            write(marker.line);
            let content;
            if (marker.file.startsWith('!')) {
                const parts = marker.file.substring(1).split(' ');
                const bin = parts[0].split('=');
                const [, cmd] = bin.length === 1 ? [bin[0], bin[0]] : [bin[0], bin[1]];

                parts[0] = cmd;
                content = execSync(parts.join(' '), { encoding: 'utf8' });
                console.info('exec', c.cyan(marker.file));
            } else {
                content = readFileSync(marker.file, 'utf8');
                content = content
                    .replace(license, '')
                    .replace(/\/\* eslint-.+ \*\//g, '')
                    .replace(/^\s*\/\/\s*prettier-ignore$\n/gm, '')
                    .trim();

                console.info('verbatim', c.cyan(marker.file));
            }
            write(content);
            write(marker.end);

            marker = null;
        } else if (marker === null) {
            write(line);
        }
    }

    writeFileSync(args[0], output.trimEnd() + '\n');
}

main();
