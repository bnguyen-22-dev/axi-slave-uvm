# RTL Design Analysis --- Simplified AXI Memory Slave

## 1. Purpose and Scope

The `axi_mem_slave` module is a simplified AXI-style memory slave used
as the Design Under Test (DUT) for this project's UVM verification
environment.

The design provides a **128-byte internal memory** and models five major
channels:

-   Write Address (`AW`)
-   Write Data (`W`)
-   Write Response (`B`)
-   Read Address (`AR`)
-   Read Data/Response (`R`)

The RTL uses separate finite-state machines (FSMs) to control these
channels and implements three burst modes: **FIXED, INCR, and WRAP**. It
also supports byte-level write selection through `WSTRB` and transfer
sizes of 1, 2, or 4 bytes.

The primary purpose of this DUT is to provide a non-trivial target for
practicing and demonstrating verification concepts including UVM
stimulus generation, monitoring, scoreboarding, assertions, functional
coverage, burst verification, and error checking.

This RTL is an **educational simplified implementation** and should not
be interpreted as a fully compliant or production-ready AXI4 slave. The
behavior documented here describes the implemented RTL and serves as the
reference specification for the UVM testbench.

------------------------------------------------------------------------

## 2. Top-Level Interface

The DUT is implemented by:

``` systemverilog
module axi_mem_slave(...);
```

and operates using `clk` and active-low `resetn`.

### 2.1 Write Address Channel

  ------------------------------------------------------------------------
  Signal           Direction                        Width DUT Usage
  ---------------- ---------------- --------------------- ----------------
  `awvalid`        Input                                1 Indicates a
                                                          write-address
                                                          request

  `awid`           Input                                4 Transaction ID

  `awlen`          Input                                4 Burst length;
                                                          DUT interprets
                                                          transfer count
                                                          as `awlen + 1`

  `awsize`         Input                                3 Transfer size: 0
                                                          = 1 byte, 1 = 2
                                                          bytes, 2 = 4
                                                          bytes

  `awaddr`         Input                               32 Starting write
                                                          address

  `awburst`        Input                                2 Selects FIXED,
                                                          INCR, or WRAP
                                                          behavior

  `awready`        Output                               1 Indicates the
                                                          write-address
                                                          FSM has reached
                                                          its ready state
  ------------------------------------------------------------------------

### 2.2 Write Data Channel

  ------------------------------------------------------------------------
  Signal           Direction                        Width DUT Usage
  ---------------- ---------------- --------------------- ----------------
  `wvalid`         Input                                1 Indicates valid
                                                          write data

  `wid`            Input                                4 Write-data
                                                          transaction ID;
                                                          not used for
                                                          internal
                                                          processing

  `wdata`          Input                               32 Write-data value

  `wstrb`          Input                                4 Selects active
                                                          byte lanes

  `wlast`          Input                                1 Indicates
                                                          completion of
                                                          the write burst
                                                          to the
                                                          write/response
                                                          control logic

  `wready`         Output                               1 Pulses as the W
                                                          FSM processes
                                                          write beats
  ------------------------------------------------------------------------

### 2.3 Write Response Channel

  ------------------------------------------------------------------------
  Signal           Direction                        Width DUT Usage
  ---------------- ---------------- --------------------- ----------------
  `bready`         Input                                1 Indicates the
                                                          requester is
                                                          ready for the
                                                          response

  `bvalid`         Output                               1 Indicates a
                                                          valid write
                                                          response

  `bid`            Output                               4 Response
                                                          transaction ID

  `bresp`          Output                               2 Write response
                                                          status
  ------------------------------------------------------------------------

### 2.4 Read Address Channel

  ------------------------------------------------------------------------
  Signal           Direction                        Width DUT Usage
  ---------------- ---------------- --------------------- ----------------
  `arvalid`        Input                                1 Indicates a
                                                          read-address
                                                          request

  `arid`           Input                                4 Read transaction
                                                          ID

  `arlen`          Input                                4 Burst length

  `arsize`         Input                                3 Transfer size: 0
                                                          = 1 byte, 1 = 2
                                                          bytes, 2 = 4
                                                          bytes

  `araddr`         Input                               32 Starting read
                                                          address

  `arburst`        Input                                2 Selects FIXED,
                                                          INCR, or WRAP
                                                          behavior

  `arready`        Output                               1 Indicates the
                                                          read-address FSM
                                                          ready state
  ------------------------------------------------------------------------

### 2.5 Read Data/Response Channel

  Signal     Direction     Width DUT Usage
  ---------- ----------- ------- -------------------------------------
  `rvalid`   Output            1 Indicates valid returned read data
  `rid`      Output            4 Read transaction ID
  `rdata`    Output           32 Returned data
  `rlast`    Output            1 Indicates the end of the read burst
  `rready`   Input             1 Indicates requester readiness
  `rresp`    Output            2 Read response status

------------------------------------------------------------------------

## 3. Internal Architecture

The DUT uses **five FSMs**:

``` text
                   axi_mem_slave

        WRITE PATH                    READ PATH

 AW ──► AW FSM                   AR ──► AR FSM
          │                               │
          ▼                               ▼
 W ───► W FSM ───────┐              R FSM ───► R
          │           │                  ▲
          │           ▼                  │
          │      ┌─────────┐             │
          │      │ 128 x 8 │─────────────┘
          │      │ Memory  │
          │      └─────────┘
          │
          ▼
       B FSM ─────────────────────► B
```

The FSMs are:

``` text
AW FSM : awidle → awstart → awreadys

W FSM  : widle → wstart → waddr_dec → wreadys → wvalids
                                      └───────────────┘

B FSM  : bidle → bdetect_last → bstart → bwait

AR FSM : aridle → arstart → arreadys

R FSM  : ridle → rstart → rwait → rvalids
                 └───────────────→ rerror
```

The design is organized primarily around **channel-specific state
machines rather than one centralized transaction controller**.

------------------------------------------------------------------------

## 4. Internal Memory Organization

The memory is declared as:

``` systemverilog
reg [7:0] mem[128] = '{default:0};
```

Therefore the DUT contains:

``` text
128 entries × 8 bits = 128 bytes
```

Each memory location represents one byte:

``` text
mem[0]    → byte 0
mem[1]    → byte 1
...
mem[127]  → byte 127
```

The external data bus is 32 bits wide, so a single operation can
manipulate up to four memory bytes depending on the transfer
configuration and `WSTRB`.

For a full write strobe (`WSTRB = 4'b1111`), the write helper functions
map the data as:

``` systemverilog
mem[address]     = wdata_temp[7:0];
mem[address + 1] = wdata_temp[15:8];
mem[address + 2] = wdata_temp[23:16];
mem[address + 3] = wdata_temp[31:24];
```

------------------------------------------------------------------------

# 5. Write Path Architecture and Operation

The write path is controlled by three cooperating FSMs:

``` text
Write Address Channel     Write Data Channel       Write Response Channel

      AW FSM                    W FSM                      B FSM
         │                        │                          │
         │                        ▼                          │
         │                   Internal Memory                │
         │                        │                          │
         └────────────────────────┴──────────────────────────┘
```

The three FSMs are not completely independent. The AW FSM observes the
state of the W FSM, while the B FSM observes `WLAST`.

A write operation can be viewed as:

``` text
1. Detect write request
        ↓
2. Process AW information
        ↓
3. Process individual WDATA beats
        ↓
4. Update internal memory
        ↓
5. WLAST indicates end of write sequence
        ↓
6. Generate BRESP/BVALID
```

## 5.1 Write Address FSM

The write-address FSM contains three states:

``` systemverilog
awidle
awstart
awreadys
```


### `awidle`

`awready` is deasserted and the FSM proceeds to `awstart`.

### `awstart`

The FSM waits for `awvalid`. When `awvalid` is observed, the DUT copies
`awaddr` into `awaddr_temp` and moves to `awreadys`.

### `awreadys`

The DUT asserts `awready` and remains in this state until the W FSM
reaches `wreadys`. The AW FSM is therefore explicitly coupled to the W
FSM.

------------------------------------------------------------------------

## 5.2 Write Data FSM

The W FSM contains five states:

### `widle`

The state initializes write-side control:

-   `wready = 0`
-   `first = 0`
-   `wlen_count = 0`
-   next state = `wstart`

### `wstart`

The FSM waits for `wvalid`. When `wvalid` is observed:

-   `wdata` is copied to `wdata_temp`
-   next state = `waddr_dec`

### `waddr_dec`

This state selects the address used for the current write.

For the first beat:

``` text
next_addr = awaddr
first     = 1
```

For later beats, `next_addr` is obtained from the address returned by
the previous write helper operation.

### `wreadys`

For a normal write beat, this state:

-   asserts `wready`
-   executes the selected burst write helper
-   moves to `wvalids`

Burst selection is:

``` text
AWBURST = 00 → data_wr_fixed()
AWBURST = 01 → data_wr_incr()
AWBURST = 10 → data_wr_wrap()
```

If `wlast` is high in `wreadys`, the W FSM returns to `widle`, clears
the burst tracking variables, and keeps `wready` low.

The burst helper `case` statement is outside the `wlast` conditional, so
it is still evaluated whenever the FSM is in `wreadys`.

### `wvalids`

This state:

-   deasserts `wready`
-   increments `wlen_count` when appropriate
-   returns to `wstart`

The resulting behavior produces repeated `wready` pulses as beats are
processed.

------------------------------------------------------------------------

## 5.3 Write Response FSM

The B FSM contains:

``` text
bidle → bdetect_last → bstart → bwait
```

### `bidle`

Initializes `bid`, `bresp`, and `bvalid`, then moves to `bdetect_last`.

### `bdetect_last`

Waits until `wlast` is asserted.

### `bstart`

The DUT:

-   drives `bid = awid`
-   asserts `bvalid`
-   generates `bresp`
-   moves to `bwait`

The implemented response behavior is:

  Condition                         `BRESP` DUT Meaning
  ------------------------------- --------- ----------------------
  `awaddr < 128 && awsize <= 2`        `00` OKAY
  `awsize > 2`                         `10` SLVERR
  Otherwise                            `11` Address/decode error

### `bwait`

The FSM waits for `bready`. When `bready` is observed, it returns to
`bidle`.

------------------------------------------------------------------------

## 5.4 Complete Write Transaction Flow

``` text
AWVALID / AW information
WVALID  / first WDATA
          │
          ├────────────► AW FSM detects request
          │
          └────────────► W FSM captures WDATA
                               │
                               ▼
                          address decode
                               │
                               ▼
                            wreadys
                               │
                     memory update + WREADY pulse
                               │
                               ▼
                            wvalids
                               │
                         increment count
                               │
                               ▼
                            wstart
                               │
                         next WDATA beat
                               │
                              ...

After expected write beats:

WLAST = 1
   │
   ├────────► W FSM returns to idle
   │
   └────────► B FSM begins response
                    │
                    ▼
               BVALID / BRESP
                    │
                 BREADY
                    │
                    ▼
                  bidle
```

------------------------------------------------------------------------

# 6. Write Burst Behavior

## 6.1 FIXED

`data_wr_fixed()` writes selected `WDATA` byte lanes according to
`WSTRB` and returns the same supplied address.

Conceptually:

``` text
current address
      │
      ├── write selected bytes
      │
      └── return same address
```

## 6.2 INCR

`data_wr_incr()` writes selected bytes and advances the returned address
according to the number of active byte lanes represented by the `WSTRB`
case.

Examples:

``` text
WSTRB = 0001 → +1
WSTRB = 0011 → +2
WSTRB = 0111 → +3
WSTRB = 1111 → +4
```

This is the implemented behavior that the UVM reference model must
reproduce.

## 6.3 WRAP

For WRAP writes, the DUT computes a boundary from `AWLEN` and `AWSIZE`.

Supported `AWLEN` values in `wrap_boundary()` are:

``` text
1  → 2 beats
3  → 4 beats
7  → 8 beats
15 → 16 beats
```

The boundary is calculated as:

``` text
boundary = (AWLEN + 1) × bytes_per_transfer
```

The `data_wr_wrap()` helper writes each selected byte and wraps an
address back by the boundary when advancing to the next byte would reach
a boundary multiple.

------------------------------------------------------------------------

# 7. Read Path Architecture and Operation

The read path is controlled by the AR FSM and R FSM:

``` text
AR channel
    │
    ▼
  AR FSM
    │
    ▼
  R FSM ◄──────── Internal Memory
    │
    ▼
RDATA / RRESP / RVALID / RLAST
```

A read operation can be viewed as:

``` text
1. Detect ARVALID
        ↓
2. Capture read address
        ↓
3. Assert ARREADY
        ↓
4. Generate read data
        ↓
5. Assert RVALID
        ↓
6. Wait for RREADY
        ↓
7. Advance burst counter/address
        ↓
8. Assert RLAST when the configured burst completes
```

## 7.1 Read Address FSM

The AR FSM contains:

``` text
aridle → arstart → arreadys → aridle
```

### `aridle`

The DUT deasserts `arready` and moves to `arstart`.

### `arstart`

The FSM waits for `arvalid`.

When `arvalid` is observed:

``` text
araddrt = araddr
next state = arreadys
```

If `arvalid` is low, the FSM remains in `arstart`.

### `arreadys`

The DUT:

``` text
ARREADY = 1
```

and immediately schedules a return to `aridle`.

Therefore, `arready` is asserted for the AR FSM's ready state after
`arvalid` has been detected.

------------------------------------------------------------------------

## 7.2 Read Data/Response FSM

The R FSM contains five states:

``` text
ridle
rstart
rwait
rvalids
rerror
```

The normal successful-read path is:

``` text
ridle
  │ ARVALID
  ▼
rstart
  │ generate RDATA/RRESP
  │ RVALID = 1
  ▼
rwait
  │ wait for RREADY
  ▼
rvalids
  │ increment beat count
  ├── more beats → rstart
  └── final beat → ridle
```

Invalid address or unsupported transfer size uses `rerror`.

------------------------------------------------------------------------

## 7.3 `ridle` --- Read Initialization

In `ridle`, the DUT clears the read-side outputs and tracking variables:

``` text
RID       = 0
RDFIRST   = 0
RDATA     = 0
RRESP     = 0
RLAST     = 0
RVALID    = 0
LEN_COUNT = 0
```

If `arvalid` is high, the R FSM moves to `rstart`. Otherwise it remains
in `ridle`.

------------------------------------------------------------------------

## 7.4 `rstart` --- Generate Read Data and Response

For a valid request:

``` text
araddrt < 128
AND
arsize <= 2
```

the DUT:

-   sets `rid = arid`
-   asserts `rvalid`
-   sets `rresp = 00`
-   selects a read helper according to `arburst`
-   moves to `rwait`

Burst selection is:

``` text
ARBURST = 00 → read_data_fixed()
ARBURST = 01 → read_data_incr()
ARBURST = 10 → read_data_wrap()
```

The state also maintains `rdfirst`, `rdnextaddr`, and `rdretaddr` to
determine the address for successive beats.

### Read Error Responses

If:

``` text
araddr >= 128
AND
arsize <= 2
```

the DUT produces:

``` text
RRESP  = 11
RVALID = 1
```

and enters `rerror`.

If:

``` text
arsize > 2
```

the DUT produces:

``` text
RRESP  = 10
RVALID = 1
```

and enters `rerror`.

------------------------------------------------------------------------

## 7.5 `rwait` --- Wait for RREADY

In `rwait`:

``` text
RVALID = 0
```

The FSM waits for `rready`.

If:

``` text
RREADY = 1
```

the FSM moves to `rvalids`.

Otherwise, it remains in `rwait`.

This behavior is part of the implemented educational DUT and is the
behavior the UVM environment should observe and verify.

------------------------------------------------------------------------

## 7.6 `rvalids` --- Advance the Read Burst

In `rvalids`, the DUT increments:

``` text
len_count = len_count + 1
```

It then compares the count with:

``` text
arlen + 1
```

If the configured number of transfers has been reached:

``` text
RLAST = 1
next state = ridle
```

Otherwise:

``` text
RLAST = 0
next state = rstart
```

This causes the R FSM to return to `rstart` and generate the next read
beat.

------------------------------------------------------------------------

## 7.7 `rerror` --- Error-Response Handling

The `rerror` state handles requests with an invalid address or
unsupported transfer size.

The state deasserts `rvalid` and uses `len_count`, `arlen`, and
`arready` to progress through the requested transfer count.

When the error sequence reaches its final transfer, the DUT:

``` text
RLAST = 1
next state = ridle
len_count = 0
```

This error behavior should be treated as part of the DUT-specific
reference behavior when constructing error tests.

------------------------------------------------------------------------

# 8. Read Burst Behavior

## 8.1 FIXED Read

`read_data_fixed()` reads from the supplied address without advancing
it.

The number of bytes returned depends on `ARSIZE`:

``` text
ARSIZE = 0 → 1 byte
ARSIZE = 1 → 2 bytes
ARSIZE = 2 → 4 bytes
```

For a four-byte read:

``` text
RDATA[7:0]   = mem[address]
RDATA[15:8]  = mem[address + 1]
RDATA[23:16] = mem[address + 2]
RDATA[31:24] = mem[address + 3]
```

## 8.2 INCR Read

`read_data_incr()` reads the configured number of bytes and returns the
next address:

``` text
ARSIZE = 0 → next address = address + 1
ARSIZE = 1 → next address = address + 2
ARSIZE = 2 → next address = address + 4
```

The R FSM stores this returned address in `rdretaddr` and uses it for
the next read beat.

## 8.3 WRAP Read

`read_data_wrap()` performs byte-level address progression while
checking the wrap boundary after each byte.

The boundary is produced by the same `wrap_boundary()` helper used by
the write path:

``` text
boundary = (ARLEN + 1) × bytes_per_transfer
```

When incrementing an address reaches a boundary multiple, the helper
subtracts the boundary to obtain the wrapped address.

------------------------------------------------------------------------

# 9. Response and Error Behavior Summary

## 9.1 Write Response

  Condition                                                  `BRESP`
  -------------------------------------------------------- ---------
  Address `< 128` and `AWSIZE <= 2`                             `00`
  `AWSIZE > 2`                                                  `10`
  Address outside implemented memory with supported size        `11`

## 9.2 Read Response

  Condition                                                  `RRESP`
  -------------------------------------------------------- ---------
  Address `< 128` and `ARSIZE <= 2`                             `00`
  `ARSIZE > 2`                                                  `10`
  Address outside implemented memory with supported size        `11`

For this project these values are interpreted as:

``` text
00 → OKAY
10 → SLVERR
11 → address/decode error
```

------------------------------------------------------------------------

# 10. DUT-Specific Behavioral Summary

The UVM environment should treat the following as the reference behavior
of this DUT:

-   The DUT contains a 128-byte byte-addressable memory.
-   Write control is divided among separate AW, W, and B FSMs.
-   Read control is divided between separate AR and R FSMs.
-   The AW FSM detects `AWVALID`, stores the address, then asserts
    `AWREADY` in its ready state.
-   The W FSM detects `WVALID`, captures `WDATA`, calculates the current
    address, updates memory, and produces a `WREADY` pulse.
-   Multiple write beats are processed by cycling through
    `wstart → waddr_dec → wreadys → wvalids`.
-   `WLAST` is used by the W FSM to terminate its write sequence and by
    the B FSM to begin response generation.
-   The B FSM asserts `BVALID` and produces `BRESP`, then waits for
    `BREADY`.
-   The AR FSM detects `ARVALID`, stores the read address, then produces
    an `ARREADY` state.
-   The R FSM generates data in `rstart`, waits for `RREADY` through its
    state sequence, counts burst beats, and produces `RLAST` when the
    configured transfer count completes.
-   FIXED, INCR, and WRAP bursts are implemented using dedicated helper
    functions.
-   Write address progression for INCR/WRAP behavior is tied to the
    implemented `WSTRB` helper logic.
-   Read address progression uses `ARSIZE`.
-   Unsupported transfer sizes and out-of-range addresses generate the
    DUT's defined error responses.

This section is the behavioral contract that should be used when
reviewing the UVM driver, monitors, scoreboard, sequences, assertions,
and functional coverage.

------------------------------------------------------------------------

# 11. Known Design Limitations

This DUT was created as a simplified educational target for verification
rather than as a production AXI4 implementation. The following
limitations are intentionally documented so that the scope of the
project is clear.

### 11.1 Simplified Channel Coordination

The channel FSMs are coupled through implementation-specific state and
control relationships. For example, the AW FSM observes the W FSM's
`wreadys` state, while the B FSM uses `WLAST` to begin response
generation.

The design therefore does not attempt to model a highly decoupled,
buffered AXI slave architecture.

### 11.2 Simplified VALID/READY Behavior

The FSMs implement a simplified request/ready sequencing model. For
example, the AW and AR FSMs first detect their respective `VALID` inputs
and assert `READY` in a later state.

The current UVM environment should verify this implemented behavior
rather than assume a different handshake architecture.

### 11.3 Limited Transaction Concurrency

The design is organized around processing the current transaction and
does not implement queues or other structures for supporting multiple
outstanding transactions.

Although ID signals exist at the interface, IDs are not used to
implement multiple concurrent transaction tracking.

### 11.4 Limited Transaction Metadata Storage

The write-address FSM stores `AWADDR` in `awaddr_temp`, while other
write-control information continues to be referenced from interface
signals during processing. Similarly, the read path stores the address
but continues to use other AR signals directly.

### 11.5 Implementation-Specific Write Address Progression

The write helper functions use `WSTRB` cases both to select bytes and,
for INCR/WRAP operations, to determine how the next address progresses.

This behavior is part of the current DUT and must be reflected by the
UVM scoreboard/reference model.

### 11.6 Limited Memory Range

The internal memory contains only 128 byte locations (`0` through
`127`). Requests outside this implemented address range are handled
using the DUT's error-response logic.

### 11.7 Educational FSM Timing

Signals such as `WREADY`, `RVALID`, and `RLAST` are generated according
to the internal multi-state sequencing described in this document. The
timing is therefore specific to this educational FSM implementation.

------------------------------------------------------------------------

# 12. Future Work --- AXI Slave Version 2

A future `AXI_slave_v2` can focus on a more protocol-faithful and
scalable architecture while keeping this version as the verified
educational reference DUT.

Potential improvements include:

-   Reworking channel control around explicit transfer/handshake events.
-   Increasing independence between AW, W, B, AR, and R channel
    processing.
-   Registering all required transaction metadata when a request is
    accepted.
-   Adding buffering/FIFOs between channels and internal transaction
    processing.
-   Supporting multiple outstanding transactions and meaningful ID
    tracking.
-   Refactoring burst address generation so transfer size and
    byte-enable behavior are handled independently.
-   Simplifying the byte-write datapath instead of enumerating every
    `WSTRB` pattern.
-   Improving response generation and transaction-completion tracking.
-   Expanding protocol assertions around channel stability, burst
    length, response timing, and transaction ordering.
-   Extending verification to cover the enhanced concurrency and
    buffering behavior.

These improvements are intentionally deferred. The current project's
primary objective is to build and demonstrate a structured **UVM
verification environment** around the documented DUT.

------------------------------------------------------------------------

# 13. Verification Contract

For the current project, this document defines the intended
interpretation of the RTL.

The verification environment should answer:

> **Does the implemented DUT behave according to the simplified behavior
> documented in this design analysis?**

The UVM environment should therefore be reviewed against this document
in the following areas:

1.  Sequence-item representation of write/read transactions.
2.  Driver timing expected by the DUT FSMs.
3.  Monitor sampling points for each channel.
4.  Scoreboard/reference-memory modeling of FIXED, INCR, and WRAP
    behavior.
5.  Error-response checking.
6.  Burst-length and end-of-transfer checking.
7.  Assertions for relevant DUT timing and stability requirements.
8.  Functional coverage of the supported DUT feature space.

Full AXI4 protocol compliance is outside the scope of the current DUT
and is reserved for future design work.
