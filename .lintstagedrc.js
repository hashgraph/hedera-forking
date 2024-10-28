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

// https://github.com/lint-staged/lint-staged?tab=readme-ov-file#using-js-configuration-files
module.exports = {
    // lint-staged appends all matched files at the end of the command
    // https://github.com/lint-staged/lint-staged?tab=readme-ov-file#what-commands-are-supported
    '*.json': 'prettier --write',

    // Check `package.json` files have appropriate `Apache-2.0` license and author
    // https://github.com/lint-staged/lint-staged?tab=readme-ov-file#example-wrap-filenames-in-single-quotes-and-run-once-per-file
    'package.json': files =>
        files.flatMap(file => [
            `grep --quiet '"license"\\s*:\\s*"Apache-2.0"' ${file}`,
            `grep --quiet '"author"\\s*:\\s*"2024 Hedera Hashgraph, LLC"' ${file}`,
        ]),

    // Check Solidity files have appropriate `Apache-2.0` license identifier
    // https://github.com/lint-staged/lint-staged?tab=readme-ov-file#example-wrap-filenames-in-single-quotes-and-run-once-per-file
    '*.sol': files =>
        files.map(file => `grep --quiet "SPDX-License-Identifier: Apache-2.0" ${file}`),

    // Apply linter and prettier rules.
    // See `eslint.config.js` and `.prettierrc.json` for details.
    '*.{js,d.ts}': ['eslint --fix', 'prettier --write'],
};
