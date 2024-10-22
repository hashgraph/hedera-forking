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

const globals = require('globals');

/** @type import('eslint').Linter.Config[] */
module.exports = [
    {
        files: ['**/*.js'],
        languageOptions: {
            sourceType: 'commonjs'
        },
    },
    {
        languageOptions: {
            globals: {
                ...globals.node,
                ...globals.mocha,
            },
        },
    },
    // @ts-ignore
    require('@eslint/js').configs.recommended,
    {
        plugins: {
            // @ts-ignore
            'license-header': require('eslint-plugin-license-header'),
        }
    },
    {
        rules: {
            'no-unused-vars': ['error', {
                'argsIgnorePattern': '^_',
                'varsIgnorePattern': '^_',
            }],
            'license-header/header': ['error', './resources/license.js.header']
        }
    }
];