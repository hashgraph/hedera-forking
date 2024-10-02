
const { resetHardhatContext } = require('hardhat/plugins-testing');
// import { HardhatRuntimeEnvironment } from "hardhat/types";
const path = require('path');

// declare module "mocha" {
//   interface Context {
//     hre: HardhatRuntimeEnvironment;
//   }
// }

describe('Hardhat Runtime Environment extension', function () {
    describe('Decode task', function () {
        useEnvironment('hardhat-project');

        it('works', async function () {
            await this.hre.run('test');
        });
    });
});

/**
 * 
 * @param {string} fixtureProjectName 
 */
function useEnvironment(fixtureProjectName) {
    beforeEach('Loading hardhat environment', function () {
        process.chdir(path.join(__dirname, fixtureProjectName));
        this.hre = require('hardhat');
    });

    afterEach('Resetting hardhat', function () {
        resetHardhatContext();
    });
}