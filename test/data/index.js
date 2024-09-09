const { strict: assert } = require('assert');
const { readdirSync, readFileSync } = require('fs');

module.exports = {
    /**
     * Tokens mock configuration.
     */
    tokens: function (/**@type {{[tokenId: string]: {symbol: string, address: string}}}*/ tokens) {
        const tokensMockPath = './test/data';
        for (const symbol of readdirSync(tokensMockPath)) {
            if (symbol.endsWith('.json') || symbol.endsWith('.js'))
                continue;
            const { token_id } = JSON.parse(readFileSync(`${tokensMockPath}/${symbol}/getToken.json`, 'utf8'));
            assert(typeof token_id === 'string');

            const [_shardNum, _realmNum, accountId] = token_id.split('.');
            const address = '0x' + parseInt(accountId).toString(16).padStart(40, '0');
            tokens[token_id] = { symbol, address };
        }
        return tokens;
    }({}),
};
