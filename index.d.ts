
/**
 *
 */
interface IMirrorNodeClient {
    getTokenById(tokenId: string, requestIdPrefix?: string): Promise<any>
    getTokenBalancesById(tokenId: string, requestIdPrefix?: string): Promise<any>
    getAccount(account: string, requestIdPrefix?: string): Promise<any>
}

/**
 *
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
 * @param address 
 * @param slot 
 * @param mirrorNodeClient 
 * @param logger 
 * @param requestIdPrefix 
 */
export function getHtsStorageAt(
    address: string,
    slot: string,
    mirrorNodeClient: IMirrorNodeClient,
    logger?: import('pino').Logger,
    requestIdPrefix?: string,
): Promise<string | null>;
