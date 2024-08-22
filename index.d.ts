
/**
 * 
 */
interface IMirrorNodeClient {
    getTokenById(tokenId: string, requestIdPrefix?: string): Promise<any>
}

/**
 * 
 */
export function getHtsCode(): string;

/**
 * 
 * @param address 
 * @param slot 
 */
export function getHtsStorageAt(
    address: string,
    slot: string,
    mirrorNodeClient: IMirrorNodeClient,
    logger?: import('pino').Logger,
    requestIdPrefix?: string,
): Promise<string | null>;
