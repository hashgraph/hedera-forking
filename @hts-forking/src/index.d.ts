
/**
 *
 */
interface IMirrorNodeClient {

    /**
     * Get token by id.
     * 
     * Returns token entity information given the id.
     * 
     * This method should call the Mirror Node API endpoint `GET /api/v1/tokens/{tokenId}`.
     * 
     * @param tokenId 
     * @param requestIdPrefix The formatted `requestId` as a prefix for logging purposes.
     */
    getTokenById(tokenId: string, requestIdPrefix?: string): Promise<Record<string, unknown> | null>;

    /**
     * 
     * @param tokenId 
     * @param accountId 
     * @param requestIdPrefix 
     */
    getBalanceOfToken(tokenId: string, accountId: string, requestIdPrefix?: string): Promise<{
        balances: {
            balance: number
        }[]
    }>;

    /**
     * Returns information for fungible token allowances for an account.
     * 
     * @param accountId Account alias or account id or evm address.
     * @param tokenId The ID of the token to return information for.
     * @param spenderId The ID of the spender to return information for.
     * @param requestIdPrefix 
     */
    getAllowanceForToken(accountId: string, tokenId: string, spenderId: string, requestIdPrefix?: string): Promise<{
        allowances: {
            amount: number,
        }[]
    }>;

    /**
     * Get account by alias, id, or evm address.
     * 
     * Return the account transactions and balance information given an account alias, an account id, or an evm address.
     * The information will be limited to at most 1000 token balances for the account as outlined in HIP-367.
     * When the timestamp parameter is supplied, we will return transactions and account state for the relevant timestamp query.
     * Balance information will be accurate to within 15 minutes of the provided timestamp query.
     * Historical ethereum nonce information is currently not available and may not be the exact value at a provided timestamp.
     * 
     * This method should call the Mirror Node API endpoint `GET /api/v1/accounts/{idOrAliasOrEvmAddress}`.
     * 
     * @param idOrAliasOrEvmAddress 
     * @param requestIdPrefix 
     */
    getAccount(idOrAliasOrEvmAddress: string, requestIdPrefix?: string): Promise<{
        account: string,
    } | null>;
}

/**
 * Gets the bytecode for the Solidity implementation of the HTS System Contract.
 */
export function getHtsCode(): string;

/**
 * This function should not throw, provided the `mirrorNodeClient` does not throw either.
 * If the `mirrorNodeClient` throws, _e.g._, due to connection issues,
 * error should be handled by the caller.
 * 
 * When the token ID corresponding to `address` does not exist,
 * the respective calls on `mirrorNodeClient` should return `null`.
 * 
 * The storage mechanism for `balanceOf` and `allowance` use a map between addresses and account IDs.
 * This allow the contract to reduce the space to marshal an account:
 * `32 bits` (or even `64 bits` if longer IDs are needed) using `accountid` (omitting the `shardId` and `realmId`) against `160 bits` using `address`.
 * This mechanism in turn allow us to marshal more than one account used in storage slots, _e.g._, `allowance`.
 * 
 * @param address 
 * @param slot 
 * @param mirrorNodeClient 
 * @param logger An object with a `trace: pino.LogFn` method.
 * @param requestIdPrefix A prefix ID to identify the request in the logs.
 */
export function getHtsStorageAt(
    address: string,
    slot: string,
    mirrorNodeClient: IMirrorNodeClient,
    logger?: Pick<import('pino').Logger, 'trace'>,
    requestIdPrefix?: string,
): Promise<string | null>;