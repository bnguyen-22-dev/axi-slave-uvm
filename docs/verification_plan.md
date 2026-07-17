# AXI Memory Slave Verification Plan

## Overview

This document describes the functional verification strategy for the AXI memory slave. The DUT consists of:

* AXI write address (AW) channel
* AXI write data (W) channel
* AXI write response (B) channel
* AXI read address (AR) channel
* AXI read data/response (R) channel
* 128-byte internal memory
* Burst address generation logic
* Byte-lane write enable (`wstrb`) logic
* Read and write finite state machines (FSMs)

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
2. Correct AXI write transactions.
3. Correct AXI read transactions.
4. Correct write followed by read operations.
5. Correct FIXED burst operation.
6. Correct INCR burst operation.
7. Correct WRAP burst operation.
8. Correct burst length handling.
9. Correct transfer size handling.
10. Correct byte-lane write strobes (`wstrb`).
11. Proper AXI handshaking on all five channels.
12. Proper write response (`bresp`).
13. Proper read response (`rresp`).
14. Proper error reporting for invalid addresses.
15. Proper error reporting for unsupported transfer sizes.
16. Correct storage and retrieval of various data patterns.
17. Robust operation under randomized transactions.

---

# Functional Test Matrix

| Test Name              | Description                                           |
| :--------------------- | :---------------------------------------------------- |
| reset_test             | Verify reset behavior                                 |
| single_write_test      | Verify a single write transaction                     |
| single_read_test       | Verify a single read transaction                      |
| write_read_test        | Write data then immediately read back                 |
| fixed_burst_test       | Verify FIXED burst write/read                         |
| incr_burst_test        | Verify INCR burst write/read                          |
| wrap_burst_test        | Verify WRAP burst write/read                          |
| transfer_size_test     | Verify 1-byte, 2-byte, and 4-byte transfers           |
| burst_length_test      | Verify burst lengths of 1, 2, 4, 8, and 16 beats      |
| partial_strobe_test    | Verify partial byte writes using `wstrb`              |
| invalid_write_test     | Write using an invalid address                        |
| invalid_read_test      | Read using an invalid address                         |
| invalid_size_test      | Verify unsupported transfer size                      |
| corner_address_test    | Verify lowest and highest valid addresses             |
| corner_data_test       | Verify boundary data values                           |
| pattern_test           | Verify special data patterns                          |
| read_before_write_test | Read memory immediately after reset                   |
| back_to_back_test      | Consecutive AXI transactions without extra idle cycle |
| random_regression      | Randomized legal AXI write/read transactions          |




# Verification Detail Table

| Category         | Test Name                      | Configuration                    | Randomized Fields                  | Expected Checks                                                  |
| :--------------- | :----------------------------- | :------------------------------- | :--------------------------------- | :--------------------------------------------------------------- |
| Reset            | `reset_test`                   | Active-low reset                 | None                               | Outputs reset correctly                                          |
| Write            | `single_write_test`            | One valid write                  | Address, Data                      | Memory updated, `bresp = OKAY`                                   |
| Read             | `single_read_test`             | One valid read                   | Address                            | Correct data returned, `rresp = OKAY`                            |
| Basic Function   | `write_read_test`              | Write then read                  | Address, Data                      | Read data matches written data                                   |
| Burst            | `fixed_burst_write_read_test`  | FIXED burst write followed by read | Address, Data                    | Same address used for every beat                                 |
| Burst            | `incr_burst_write_read_test`   | INCR burst write followed by read  | Address, Data                    | Address increments correctly                                     |
| Burst            | `wrap_burst_write_read_test`   | WRAP burst write followed by read  | Address, Data                    | Address wraps correctly                                          |
| Transfer Size    | `transfer_size_test`           | Size = 1B, 2B, 4B                | Address, Size                      | Address increment matches transfer size                          |
| Burst Length     | `burst_length_test`            | `len = 0, 1, 3, 7, 15`           | Burst Length                       | Number of beats equals `len + 1`                                 |
| Write Strobe     | `partial_strobe_test`          | Various `wstrb` values           | Data, `wstrb`                      | Only selected byte lanes updated                                 |
| Error Handling   | `invalid_write_addr_test`      | Write with address >= 128        | Invalid Address                    | Write error response, memory unchanged                           |
| Error Handling   | `invalid_read_addr_test`       | Read with address >= 128         | Invalid Address                    | Read error response generated                                    |
| Error Handling   | `invalid_write_size_test`      | Write with size > 4 bytes        | Invalid Size                       | Write `SLVERR` response, memory unchanged                        |
| Error Handling   | `invalid_read_size_test`       | Read with size > 4 bytes         | Invalid Size                       | Read `SLVERR` response generated                                 |
| Address          | `corner_address_test`          | Address = 0, 127, 128            | None                               | Valid accesses succeed, invalid fails                            |
| Data             | `corner_data_test`             | 0x00000000, 0xFFFFFFFF           | None                               | Correct readback                                                 |
| Data Pattern     | `pattern_test`                 | Walking-1, Walking-0, Alternating| Data                               | Correct readback                                                 |
| Initialization   | `read_before_write_test`       | Read after reset                 | Address                            | Returns initialized memory value                                 |
| Regression       | `random_regression`            | Random legal transactions        | Address, Data, Burst, Size, Length, `wstrb` | Scoreboard matches DUT                               |

> **Note:** Burst-specific tests always use **`len > 0`** (i.e., at least **2 beats**) so that the DUT exercises true burst behavior. Since AXI defines the number of transfer beats as **`len + 1`**, a value of **`len = 0`** represents a single-beat transfer and is already covered by the basic write/read tests.



# Coverage Matrix

| Feature                              | Coverage Goal |
| :----------------------------------- | :-----------: |
| Reset                                |       ✓       |
| Single write                         |       ✓       |
| Single read                          |       ✓       |
| Write followed by read               |       ✓       |
| FIXED burst                          |       ✓       |
| INCR burst                           |       ✓       |
| WRAP burst                           |       ✓       |
| 1-byte transfer                      |       ✓       |
| 2-byte transfer                      |       ✓       |
| 4-byte transfer                      |       ✓       |
| Burst length = 1 beat                |       ✓       |
| Burst length = 2 beats               |       ✓       |
| Burst length = 4 beats               |       ✓       |
| Burst length = 8 beats               |       ✓       |
| Burst length = 16 beats              |       ✓       |
| Partial write strobes                |       ✓       |
| Full write strobes                   |       ✓       |
| Address 0                            |       ✓       |
| Address 127                          |       ✓       |
| Invalid address                      |       ✓       |
| Invalid transfer size                |       ✓       |
| All-zero data                        |       ✓       |
| All-one data                         |       ✓       |
| Alternating pattern (0xAAAAAAAA)     |       ✓       |
| Alternating pattern (0x55555555)     |       ✓       |
| Walking-1 pattern                    |       ✓       |
| Walking-0 pattern                    |       ✓       |
| Read before write                    |       ✓       |
| Back-to-back transactions            |       ✓       |
| Write response (`bresp`)             |       ✓       |
| Read response (`rresp`)              |       ✓       |
| Random regression                    |       ✓       |