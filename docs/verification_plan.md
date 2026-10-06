# AXI Memory Slave Verification Plan

## Overview

This document describes the functional verification strategy for the
**simplified AXI memory slave** used as the Design Under Test (DUT) in this project.

The DUT is an educational AXI-inspired implementation intended primarily
as a target for UVM and assertion-based verification. The verification
plan targets the implemented RTL behavior documented in
`RTL_DESIGN_ANALYSIS.md` rather than full AXI4 protocol compliance.

The DUT consists of:

- AXI-style write address (AW) channel
- AXI-style write data (W) channel
- AXI-style write response (B) channel
- AXI-style read address (AR) channel
- AXI-style read data/response (R) channel
- 128-byte internal memory
- Burst address generation logic
- Byte-lane write enable (`wstrb`) logic
- Read and write finite state machines (FSMs)

Supported features:

* AXI write transactions
* AXI read transactions
* FIXED burst
* INCR burst
* WRAP burst
* Burst lengths from 1 to 16 beats (`len + 1`)
* Transfer sizes:
  * 1 byte
  * 2 bytes
  * 4 bytes
* Byte write strobes (`wstrb`)
* Active-low asynchronous reset
* Error response for:
  * Invalid address
  * Unsupported transfer size

---

# Verification Objectives

The verification environment shall verify:

1. Correct reset behavior.
2. Correct DUT write transaction behavior.
3. Correct DUT read transaction behavior.
4. Correct write followed by read operations.
5. Correct FIXED burst operation.
6. Correct INCR burst operation.
7. Correct WRAP burst operation.
8. Correct burst length handling.
9. Correct transfer size handling.
10. Correct byte-lane write strobes (`wstrb`).
11. Correct channel sequencing and `VALID`/`READY` behavior according to the implemented DUT FSMs.
12. Proper write response (`bresp`).
13. Proper read response (`rresp`).
14. Proper error reporting for invalid addresses.
15. Proper error reporting for unsupported transfer sizes.
16. Correct storage and retrieval of various data patterns.
17. Robust operation under randomized transactions.

---

# Functional Test Matrix

| Test Name                    | Description |
| :--------------------------- | :---------- |
| reset_test                   | Verify reset behavior |
| single_write_test            | Verify a single write transaction |
| single_read_test             | Verify a single read transaction |
| write_read_test              | Write data then immediately read back |
| fixed_burst_test             | Verify FIXED burst write/read |
| incr_burst_test              | Verify INCR burst write/read |
| wrap_burst_test              | Verify WRAP burst write/read |
| transfer_size_test           | Verify 1-byte, 2-byte, and 4-byte transfers |
| burst_length_test            | Verify burst lengths of 1, 2, 4, 8, and 16 beats |
| partial_strobe_test          | Verify partial byte writes using `wstrb` |
| invalid_write_addr_test      | Verify write behavior with an invalid address |
| invalid_read_addr_test       | Verify read behavior with an invalid address |
| invalid_write_size_test      | Verify write behavior with an unsupported transfer size |
| invalid_read_size_test       | Verify read behavior with an unsupported transfer size |
| corner_address_test          | Verify accesses near the implemented memory boundaries |
| corner_data_test             | Verify boundary data values |
| pattern_test                 | Verify special data patterns |
| read_before_write_test       | Read memory immediately after reset |
| back_to_back_test            | Verify consecutive DUT transactions |
| random_regression            | Randomized legal DUT write/read transactions |



# Verification Detail Table

| Category | Test Name | Configuration | Randomized Fields | Expected Checks |
| :--- | :--- | :--- | :--- | :--- |
| Reset | `reset_test` | Active-low reset | None | Outputs reset correctly |
| Write | `single_write_test` | One valid write | Address, Data | Memory updated, `bresp = OKAY` |
| Read | `single_read_test` | One valid read | Address | Correct data returned, `rresp = OKAY` |
| Basic Function | `write_read_test` | Write then read | Address, Data | Read data matches written data |
| Burst | `fixed_burst_write_read_test` | FIXED burst write followed by read | Address, Data | Same address used for every beat |
| Burst | `incr_burst_write_read_test` | INCR burst write followed by read | Address, Data | Write/read data and address progression match the implemented DUT INCR behavior |
| Burst | `wrap_burst_write_read_test` | WRAP burst write followed by read | Address, Data | Address wraps according to the implemented DUT WRAP behavior |
| Transfer Size | `transfer_size_test` | Size = 1B, 2B, 4B | Address, Size | Correct data transfer for each supported size according to the implemented DUT behavior |
| Burst Length | `burst_length_test` | `len = 0, 1, 2, 3, 7, 10, 15` | Burst Length | Number of beats equals `len + 1` |
| Write Strobe | `partial_strobe_test` | Various `wstrb` values | Data, `wstrb` | Only selected byte lanes updated |
| Error Handling | `invalid_write_addr_test` | Write with address >= 128 | Invalid Address | Write error response generated, memory unchanged |
| Error Handling | `invalid_read_addr_test` | Read with address >= 128 | Invalid Address | Read error response generated |
| Error Handling | `invalid_write_size_test` | Write with size > 4 bytes | Invalid Size | Write `SLVERR` response generated, memory unchanged |
| Error Handling | `invalid_read_size_test` | Read with size > 4 bytes | Invalid Size | Read `SLVERR` response generated |
| Address | `corner_address_test` | Accesses near addresses 0 and 127, plus invalid address 128 | Address, Size | Behavior matches the DUT memory-boundary and error-response logic |
| Data | `corner_data_test` | `0x00000000`, `0xFFFFFFFF` | None | Correct readback |
| Data Pattern | `pattern_test` | Walking-1, Walking-0, Alternating | Data | Correct readback |
| Initialization | `read_before_write_test` | Read after reset | Address | Returns initialized memory value |
| Regression | `random_regression` | Random legal transactions | Address, Data, Burst, Size, Length, `wstrb` | Scoreboard matches DUT behavior |

> **Burst Length Convention:** The DUT interprets the burst length fields
> (`awlen` / `arlen`) as `number_of_beats - 1`. Therefore, a transaction
> with `len = N` contains exactly `N + 1` data beats.


# Verification Feature Matrix

> This matrix tracks DUT features exercised by the planned directed and
> randomized tests. SystemVerilog functional coverage is not currently
> implemented in this project.

| Feature | Test Coverage |
| :--- | :--- |
| Reset | `reset_test` |
| Single Write | `single_write_test` |
| Single Read | `single_read_test` |
| Write → Read | `write_read_test` |
| FIXED Burst | `fixed_burst_write_read_test` |
| INCR Burst | `incr_burst_write_read_test` |
| WRAP Burst | `wrap_burst_write_read_test` |
| Transfer Size = 1B | `transfer_size_test` |
| Transfer Size = 2B | `transfer_size_test` |
| Transfer Size = 4B | `transfer_size_test` |
| Burst Length = 1 | `burst_length_test` |
| Burst Length = 2 | `burst_length_test` |
| Burst Length = 4 | `burst_length_test` |
| Burst Length = 8 | `burst_length_test` |
| Burst Length = 16 | `burst_length_test` |
| Partial Write Strobes | `partial_strobe_test` |
| Invalid Write Address | `invalid_write_addr_test` |
| Invalid Read Address | `invalid_read_addr_test` |
| Invalid Write Size | `invalid_write_size_test` |
| Invalid Read Size | `invalid_read_size_test` |
| Memory Boundary Accesses | `corner_address_test` |
| Data = `0x00000000` | `corner_data_test` |
| Data = `0xFFFFFFFF` | `corner_data_test` |
| Walking-1 Pattern | `pattern_test` |
| Walking-0 Pattern | `pattern_test` |
| Alternating Pattern | `pattern_test` |
| Read Before Write | `read_before_write_test` |
| Random Legal Transactions | `random_regression` |

# Randomization Strategy

Constrained-random stimulus is used to exercise different combinations of
supported DUT transaction parameters while keeping generated transactions
within the behavior implemented by the simplified AXI DUT.

The following transaction fields may be randomized:

- Address
- Write data
- Burst type
- Transfer size
- Burst length
- Write strobe (`wstrb`)

Legal randomized transactions are constrained to the DUT-supported
configuration space:

```text
address < 128
size ∈ {0, 1, 2}
burst ∈ {FIXED, INCR, WRAP}
len ∈ {0, 1, 3, 7, 15}
wstrb ∈ {0001 ... 1111}