// https://github.com/lint-staged/lint-staged?tab=readme-ov-file#using-js-configuration-files
module.exports = {
    // lint-staged appends all matched files at the end of the command
    // https://github.com/lint-staged/lint-staged?tab=readme-ov-file#what-commands-are-supported
    'out/HtsSystemContract.sol/HtsSystemContract.json': 'prettier --write',

    // Check Solidity files have appropriate `Apache-2.0` license identifier
    // https://github.com/lint-staged/lint-staged?tab=readme-ov-file#example-wrap-filenames-in-single-quotes-and-run-once-per-file
    '*.sol': files => files.map(file => `grep --quiet "SPDX-License-Identifier: Apache-2.0" ${file}`),
};