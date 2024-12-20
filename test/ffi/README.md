## Purpose of the project

This simple application was created to communicate directly with a Hedera node running in the background using the FFI interface. It leverages the Hedera SDK library to handle communication with the HTS by interfacing directly with the node's gRPC interface, eliminating the need to implement and maintain the communication layer ourselves.

A full Hedera node must be running in the background to demonstrate that the communication works. The next step would involve replacing the full Hedera node with a lightweight standalone application that supports only HTS functionalities and uses a storage state downloaded from the forked network.

Achieving this would require further development and rebuilding the HederaServices application, as outlined below. This simple PoC has been prepared to showcase the feasibility of this solution, though it is not fully ready and will require additional effort to complete.

## Prerequisites for Running Hedera FFI Tests

All commands in this README are intended to be executed from the main directory of the repository.

### Step 1: Add `hedera-call` Script to your PATH

To make the `hedera-call` script callable, include it in your system's PATH environment variable. Run the following
command:

```bash
export PATH="./test/ffi:$PATH"
```

### Step 2: Start the Hedera Local Node

Ensure that the Hedera local node is running on its default ports before executing any scripts.

```bash
hedera start
```

## Running Tests for FFI with Local Node

To execute the FFI tests specifically for the `LocalNodeToken` scenario, use the following command:

```bash
forge test --match-path=test/LocalNodeToken.t.sol
```

## Stopping Hedera Local Node

Once the tests are completed, remember to shut down the Hedera local node to save resources. Use the command below:

```bash
hedera stop
```

## Current Challenges:

1. Gas Cost Handling:
   - Gas costs are fully covered by the operator on the HTS side, meaning normal transaction signer costs are bypassed.
   - An alternative approach (removing signature checks) was previously explored but would require significant changes to HTS due to the absence of a `from` field in transactions.
2. Account Balance Discrepancies:
   - Accounts created via the SDK must have a predefined balance on the Hedera side, which differs from the Foundry side. This leads to balance mismatches at the outset.
3. Transaction Reverting and Snapshots:
   - Properly handling transaction reverts and creating snapshots of the Hedera local node state will require:
   - Adding new methods to the gRPC API.
   - Potentially adopting a completely new approach to state management.
4. Local Node Lifecycle Management:
   - The current solution relies on the Hedera local node running continuously in the background, which is impractical.
   - Potential solutions:
   - Option 1: Start the local node before tests and stop it afterward. This is easier but not fail-safe (e.g., tests being interrupted unexpectedly).
   - Option 2: Start a new local node instance for each operation and terminate it once the result is returned. While more robust, this approach would require:
     - Extracting only HTS functionality from the Hedera architecture.
     - Optimizing startup times, which may not be feasible given the Java-based implementation.
5. Remote State Fetching:
   - To support forking, remote state fetching is a crucial feature for the solution's usability.
