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
            sourceType: 'commonjs',
        },
    },
    {
        // https://eslint.org/docs/latest/use/configure/ignore#ignoring-files
        ignores: ['lib/'],
    },
    {
        languageOptions: {
            globals: {
                ...globals.node,
                ...globals.mocha,
            },
        },
    },
    // @ts-expect-error: Could not find a declaration file for module '@eslint/js'
    require('@eslint/js').configs.recommended,
    // @ts-expect-error: Could not find a declaration file for module 'eslint-plugin-mocha'
    require('eslint-plugin-mocha').configs.flat.recommended,
    ...require('typescript-eslint').configs.recommended,
    {
        plugins: {
            // @ts-expect-error: Could not find a declaration file for module 'eslint-plugin-license-header'
            'license-header': require('eslint-plugin-license-header'),
        },
    },
    {
        rules: {
            // https://eslint.org/docs/latest/rules/prefer-const
            'prefer-const': [
                'warn',
                {
                    'destructuring': 'all',
                },
            ],

            // https://github.com/nikku/eslint-plugin-license-header?tab=readme-ov-file#eslint-plugin-license-header
            'license-header/header': ['error', './resources/license.js.header'],

            // Disable to use dynamically generated tests https://mochajs.org/#dynamically-generating-tests
            // https://github.com/lo1tuma/eslint-plugin-mocha/blob/main/docs/rules/no-setup-in-describe.md
            'mocha/no-setup-in-describe': 'off',

            // https://typescript-eslint.io/rules/no-unused-vars
            '@typescript-eslint/no-unused-vars': [
                'error',
                {
                    'argsIgnorePattern': '^_',
                    'varsIgnorePattern': '^_',
                },
            ],
            '@typescript-eslint/no-require-imports': 'off',
            '@typescript-eslint/no-unused-expressions': 'off',
        },
    },
];
