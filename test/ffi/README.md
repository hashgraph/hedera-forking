## Prerequisites for Running Hedera FFI Tests

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
