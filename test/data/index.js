const { readdirSync, readFileSync } = require('fs');

module.exports = {
    /**
     * Tokens mock configuration.
     * 
     * @type {{[tokenId: string]: {symbol: string, address: string}}}
     */
    tokens: function (tokens) {
        const tokensMockPath = './test/data';
        for (const symbol of readdirSync(tokensMockPath)) {
            if (symbol.endsWith('.json') || symbol.endsWith('.js'))
                continue;
            const { token_id } = JSON.parse(readFileSync(`${tokensMockPath}/${symbol}/getToken.json`));
            const [_shardNum, _realmNum, accountId] = token_id.split('.');
            const address = '0x' + parseInt(accountId).toString(16).padStart(40, '0');
            tokens[token_id] = { symbol, address };
        }
        return tokens;
    }({}),
};
