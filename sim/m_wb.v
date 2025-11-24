module m_wb #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 64,
    parameter BYTE_WIDTH   = DATA_WIDTH / 8,
    parameter WBS_ADDR_LSB = $clog2(BYTE_WIDTH)
)(
    input  wire                          aclk,
    input  wire                          aresetn,    // active-low sync reset

    // Command interface (pulse start to begin operation)
    input  wire [ADDR_WIDTH-1:WBS_ADDR_LSB] addr,
    input  wire [DATA_WIDTH-1:0]            data_i,     // data for write operations
    input  wire [BYTE_WIDTH-1:0]            sel,        // byte-enable/byte select
    input  wire                             we,         // Write-enable: Whether it is a write or read transaction
    input  wire                             start,      // 1-cycle pulse to begin transaction
    output reg  [DATA_WIDTH-1:0]            data_o,     // latched data from read operations
    output reg                              done,       // 1-cycle pulse when transaction finished

    // Wishbone B4 Classic master signals (standard directions)
    output reg                              m_wb_cyc,   // cycle valid
    output reg                              m_wb_stb,   // strobe/request
    output reg                              m_wb_we,    // 1=write, 0=read
    output reg [ADDR_WIDTH-1:WBS_ADDR_LSB]  m_wb_adr,   // word address (no byte offset bits)
    output reg [DATA_WIDTH-1:0]             m_wb_dat_o, // write data from master
    output reg [BYTE_WIDTH-1:0]             m_wb_sel,   // byte-enable/byte select

    input  wire [DATA_WIDTH-1:0]            m_wb_dat_i, // read data from slave
    input  wire                             m_wb_ack,   // 1-cycle ack from slave
    input  wire                             m_wb_stall  // stall/back-pressure from slave
);

    // State machine parameter definitions
    localparam S_IDLE = 2'b00;
    localparam S_REQ  = 2'b01;
    localparam S_DONE = 2'b10;

    // State registers
    reg [1:0] state, next_state;

    // Internal registers to hold command interface signals for the duration of the transaction
    reg [ADDR_WIDTH-1:WBS_ADDR_LSB] r_addr;
    reg [DATA_WIDTH-1:0]            r_data;
    reg [BYTE_WIDTH-1:0]            r_sel;
    reg                             r_we;


    // Sequential logic for state and register updates
    always @(posedge aclk) begin
        if (!aresetn) begin
            state  <= S_IDLE;
            r_addr <= {ADDR_WIDTH-WBS_ADDR_LSB{1'b0}};
            r_data <= {DATA_WIDTH{1'b0}};
            r_sel  <= {BYTE_WIDTH{1'b0}};
            r_we   <= 1'b0;
            data_o <= {DATA_WIDTH{1'b0}}; // Reset read data output port
        end else begin
            state <= next_state;
            
            // Latch command inputs when a new transaction starts from the IDLE state
            if (start && (state == S_IDLE)) begin
                r_addr <= addr;
                r_data <= data_i; // Latch write data from the new 'data_i' input
                r_sel  <= sel;
                r_we   <= we;
            end

            // When a read transaction is acknowledged by the slave, latch the incoming data
            if (state == S_REQ && m_wb_ack && !m_wb_stall && !r_we) begin
                data_o <= m_wb_dat_i;
            end
        end
    end

    // Combinational logic for FSM transitions and output generation
    always @(*) begin
        // Set default values for all outputs to avoid latches
        next_state = state;
        done       = 1'b0;
        m_wb_cyc   = 1'b0;
        m_wb_stb   = 1'b0;
        m_wb_we    = 1'b0;
        m_wb_adr   = {ADDR_WIDTH-WBS_ADDR_LSB{1'b0}};
        m_wb_dat_o = {DATA_WIDTH{1'b0}};
        m_wb_sel   = {BYTE_WIDTH{1'b0}};

        case (state)
            S_IDLE: begin
                // Wait for a start signal to begin a new transaction.
                // All Wishbone outputs remain de-asserted.
                if (start) begin
                    next_state = S_REQ;
                end
            end

            S_REQ: begin
                // Drive the Wishbone bus with the latched command data.
                // Assert CYC and STB to signal a valid transaction.
                m_wb_cyc   = 1'b1;
                m_wb_stb   = 1'b1;
                m_wb_we    = r_we;
                m_wb_adr   = r_addr;
                m_wb_dat_o = r_data; // Drive latched write data onto the wishbone bus
                m_wb_sel   = r_sel;
                
                // Wait for acknowledgement from the slave, ensuring no stall condition.
                // The master holds the request active until ACK is received.
                if (m_wb_ack && !m_wb_stall) begin
                    next_state = S_DONE;
                end else begin
                    next_state = S_REQ;
                end
            end
            
            S_DONE: begin
                // Transaction has been acknowledged and is now complete.
                // Pulse the 'done' signal for one cycle.
                done = 1'b1;
                // De-assert all wishbone outputs by leaving them at their default values.
                // Transition back to IDLE to await the next command.
                next_state = S_IDLE;
            end
            
            default: begin
                // In case of an illegal state, return to the IDLE state.
                next_state = S_IDLE;
            end
        endcase
    end

endmodule