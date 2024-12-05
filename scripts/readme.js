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

const { readFileSync, writeFileSync } = require('fs');
const c = require('ansi-colors');
const { execSync } = require('child_process');

function main() {
    const BEGIN_MARKER = /^<!-- (.+) -->$/;
    const END_MARKER = '<!-- -->';

    const args = process.argv.slice(2);
    if (args.length !== 1) {
        throw new Error('Invalid number of arguments');
    }

    const readme = readFileSync(args[0], 'utf8');

    /** @type {{line: string, file: string} | null} */
    let marker = null;
    let output = '';
    const write = (/** @type string */ line) => (output += line + '\n');

    for (const line of readme.split('\n')) {
        const trimmedLine = line.trim();
        // const parts = trimmedLine.split(' ');
        const m = trimmedLine.match(BEGIN_MARKER);
        // if (parts.length >= 2 && parts[0].match(BEGIN_MARKER) && parts[1] !== '' && marker === null) {
        if (m !== null && marker === null) {
            marker = { line: trimmedLine, file: m[1] };
            process.stdout.write(`Opening marker ${c.magenta(marker.file)} .. `);
        } else if (trimmedLine === END_MARKER && marker !== null) {
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
                    .replace('#!/usr/bin/env node', '')
                    .replace(/\/\* eslint-.+ \*\//g, '')
                    .trim();

                console.info('verbatim', c.cyan(marker.file));
            }
            write(content);
            write(END_MARKER);

            marker = null;
        } else if (marker === null) {
            write(line);
        }
    }

    writeFileSync(args[0], output.trimEnd() + '\n');
}

main();
