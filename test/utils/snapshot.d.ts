export {};

declare global {
    export namespace Chai {
        interface Assertion {
            matchCall(calldata: string, decoded: unknown, ctx: Mocha.Context): Assertion;
        }
    }
}
