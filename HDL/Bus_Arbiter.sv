//
// KFPC-XT Bus_Arbiter
// Written by kitune-san
//
module BUS_ARBITER (
    input   logic           clock,
    input   logic           reset,

    // CPU Bus
    input   logic   [19:0]  cpu_address,
    input   logic   [7:0]   cpu_data_bus,
    input   logic   [2:0]   processor_status,
    input   logic           processor_lock_n,

    // Wait Logic
    input   logic           dma_ready,
    output  logic           dma_wait_n,

    // Bus Control
    output  logic           address_enable_n,   // AENBRD
    output  logic           io_write_n,
    input   logic           io_write_n_ext,
    output  logic           io_write_n_direction,
    output  logic           io_read_n,
    input   logic           io_read_n_ext,
    output  logic           io_read_n_direction,
    output  logic           memory_write_n,
    input   logic           memory_write_n_ext,
    output  logic           memory_write_n_direction,
    output  logic           memory_read_n,
    input   logic           memory_read_n_ext,
    output  logic           memory_read_n_direction,
    output  logic   [19:0]  address,
    input   logic   [19:0]  address_ext,
    output  logic           address_direction,
    input   logic   [7:0]   data_bus_ext,
    output  logic   [7:0]   internal_data_bus,
    output  logic           data_bus_direction,
    output  logic           interrupt_acknowledge_n,
    input   logic           dma_chip_select_n,
    input   logic           dma_page_chip_select_n,

    // I/O
    output  logic           terminal_count,
    input   logic   [3:0]   dma_request,
    output  logic   [3:0]   dma_acknowledge_n
);

    //
    // Hold Acknowledge Signal
    //
    logic   hold_request_ff_1;
    logic   hold_request_ff_2;
    logic   hold_acknowledge;
    logic   hold_request;

    // NOTE: POSEDGE
    always_ff @(posedge clock, posedge reset) begin
        if (reset)
            hold_request_ff_1 <= 1'b0;
        else if (processor_status[0] & processor_status[1] & processor_lock_n & hold_request)
            hold_request_ff_1 <= 1'b1;
        else
            hold_request_ff_1 <= 1'b0;
    end

    // NOTE: NEGEDGE
    always_ff @(negedge clock, posedge reset) begin
        if (reset)
            hold_request_ff_2 <= 1'b0;
        else if (~hold_request)
            hold_request_ff_2 <= 1'b0;
        else if (hold_request_ff_2)
            hold_request_ff_2 <= 1'b1;
        else
            hold_request_ff_2 <= hold_request_ff_1;
    end

    assign  hold_acknowledge = (hold_request) ? hold_request_ff_2 : 1'b0;


    //
    // Address/Command Enable Signal
    //
    // NOTE: POSEDGE
    always_ff @(posedge clock, posedge reset) begin
        if (reset)
            address_enable_n <= 1'b0;
        else
            address_enable_n <= hold_acknowledge;
    end

    assign  command_enable = ~address_enable_n;


    //
    // DMA Wait Signal
    //
    logic   dma_wait;

    // NOTE: POSEDGE
    always_ff @(posedge clock, posedge reset) begin
        if (reset)
            dma_wait <= 1'b0;
        else
            dma_wait <= address_enable_n;
    end

    assign dma_wait_n = ~dma_wait;


    //
    // DMA Enable Signal
    //
    wire    dma_enable_n = ~(dma_wait & address_enable_n);


    //
    // 8288 Bus Controller
    //
    logic           bc_io_write_n;
    logic           bc_io_read_n;
    logic           bc_enable_io;
    logic           bc_memory_write_n;
    logic           bc_memory_read_n;
    logic           bc_memory_enable;
    logic           direction_transmit_or_receive_n;
    logic           data_enable;

    KF8288 u_KF8288 (
        .clock                              (clock),
        .reset                              (reset),
        .address_enable_n                   (address_enable_n),
        .command_enable                     (~address_enable_n),
        .io_bus_mode                        (1'b0),
        .processor_status                   (processor_status),
        .enable_io_command                  (bc_enable_io),
        .advanced_io_write_command_n        (bc_io_write_n),
        //.io_write_command_n                 (),
        .io_read_command_n                  (bc_io_read_n),
        .interrupt_acknowledge_n            (interrupt_acknowledge_n),
        .enable_memory_command              (bc_memory_enable),
        .advanced_memory_write_command_n    (bc_memory_write_n),
        //.memory_write_command_n             (),
        .memory_read_command_n              (bc_memory_read_n),
        .direction_transmit_or_receive_n    (direction_transmit_or_receive_n),
        .data_enable                        (data_enable)
        //.master_cascade_enable              (),
        //.peripheral_data_enable_n           (),
        //.address_latch_enable               ()
    );


    //
    // 8237 (DMA Controller)
    //
    logic           dma_io_write_n;
    logic   [7:0]   dma_data_out;
    logic           dma_io_read_n;
    logic   [15:0]  dma_address_out;
    logic           dma_memory_read_n;
    logic           dma_memory_write_n;

    KF8237 u_KF8237 (
        .clock                              (clock),
        .reset                              (reset),
        .chip_select_n                      (dma_chip_select_n),
        .ready                              (dma_ready),
        .hold_acknowledge                   (hold_acknowledge),
        .dma_request                        (dma_request),
        .data_bus_in                        (internal_data_bus),
        .data_bus_out                       (dma_data_out),
        .io_read_n_in                       (io_read_n),
        .io_read_n_out                      (dma_io_read_n),
        //.io_read_n_io                       (),
        .io_write_n_in                      (io_write_n),
        .io_write_n_out                     (dma_io_write_n),
        //.io_write_n_io                      (),
        .end_of_process_n_in                (1'b1),
        .end_of_process_n_out               (terminal_count),
        .address_in                         (address[3:0]),
        .address_out                        (dma_address_out),
        //.output_highst_address              (),
        .hold_request                       (hold_request),
        .dma_acknowledge                    (dma_acknowledge_n),
        //.address_enable                     (),
        //.address_strobe                     (),
        .memory_read_n                      (dma_memory_read_n),
        .memory_write_n                     (dma_memory_write_n)
    );


    //
    // 74xx670 (DMA Page Register)
    //
    logic   [1:0]   bit_select[4] = '{ 2'b00, 2'b01, 2'b10, 2'b11 };
    logic   [3:0]   dma_page_register[4];

    genvar dma_page_i;
    generate
    for (dma_page_i = 0; dma_page_i < 4; dma_page_i = dma_page_i + 1) begin : DMA_PAGE_REGISTERS
        always_ff @(negedge clock, posedge reset) begin
            if (reset)
                dma_page_register[dma_page_i] <= 0;
            else if ((~dma_page_chip_select_n) && (io_write_n) && (bit_select[dma_page_i] == address[1:0]))
                dma_page_register[dma_page_i] <= internal_data_bus[3:0];
            else
                dma_page_register[dma_page_i] <= dma_page_register[dma_page_i];
        end
    end
    endgenerate


    //
    // R/W Command Signals
    //
    wire    ab_io_write_n               = ~((~bc_io_write_n & bc_enable_io) | ~dma_io_write_n);
    wire    ab_io_read_n                = ~((~bc_io_read_n  & bc_enable_io) | ~dma_io_read_n);
    wire    ab_memory_write_n           = ~((~bc_memory_write_n & bc_memory_enable) | ~dma_memory_write_n);
    wire    ab_memory_read_n            = ~((~bc_memory_read_n  & bc_memory_enable) | ~dma_memory_read_n);
    assign  io_write_n_direction        = ab_io_write_n;
    assign  io_read_n_direction         = ab_io_read_n;
    assign  memory_write_n_direction    = ab_memory_write_n;
    assign  memory_read_n_direction     = ab_memory_read_n;
    assign  io_write_n                  = io_write_n_direction     ? io_write_n_ext     : ab_io_write_n;
    assign  io_read_n                   = io_read_n_direction      ? io_read_n_ext      : ab_io_read_n;
    assign  memory_write_n              = memory_write_n_direction ? memory_write_n_ext : ab_memory_write_n;
    assign  memory_read_n               = memory_read_n_direction  ? memory_read_n_ext  : ab_memory_read_n;


    //
    // Address
    //
    always_comb begin
        if (~dma_enable_n)
            if (~dma_acknowledge_n[2]) begin
                address           = {dma_page_register[1], dma_address_out};
                address_direction = 1'b0;
            end
            else if (~dma_acknowledge_n[3]) begin
                address           = {dma_page_register[2], dma_address_out};
                address_direction = 1'b0;
            end
            else begin
                address           = {dma_page_register[3], dma_address_out};
                address_direction = 1'b0;
            end
        else if (~address_enable_n) begin
            address           = cpu_address;
            address_direction = 1'b0;
        end
        else begin
            address           = address_ext;
            address_direction = 1'b1;
        end
    end


    //
    // Data Bus
    //
    always_comb begin
        if (~interrupt_acknowledge_n) begin
            internal_data_bus  = data_bus_ext;
            data_bus_direction = 1'b0;
        end
        else if ((data_enable) && (direction_transmit_or_receive_n)) begin
            internal_data_bus  = cpu_data_bus;
            data_bus_direction = 1'b0;
        end
        else if ((~dma_chip_select_n) && (io_read_n)) begin
            internal_data_bus  = dma_data_out;
            data_bus_direction = 1'b0;
        end
        else begin
            internal_data_bus  = data_bus_ext;
            data_bus_direction = 1'b1;
        end
    end


endmodule

