//
// KFPC-XT Peripherals
// Written by kitune-san
//
module PERIPHERALS #(
    parameter ps2_over_time = 16'd1000
) (
    input   logic           clock,
    input   logic           peripheral_clock,
    input   logic           reset,
    // CPU
    output  logic           interrupt_to_cpu,
    // Bus Arbiter
    input   logic           interrupt_acknowledge_n,
    output  logic           dma_chip_select_n,
    output  logic           dma_page_chip_select_n,
    // I/O Ports
    input   logic   [19:0]  address,
    input   logic   [7:0]   internal_data_bus,
    output  logic   [7:0]   data_bus_out,
    output  logic           data_bus_out_from_chipset,
    input   logic   [7:0]   interrupt_request,
    input   logic           io_read_n,
    input   logic           io_write_n,
    input   logic           memory_read_n,
    input   logic           memory_write_n,
    input   logic           address_enable_n,
    // Peripherals
    output  logic   [2:0]   timer_counter_out,
    output  logic           speaker_out,
    output  logic   [7:0]   port_a_out,
    output  logic           port_a_io,
    input   logic   [7:0]   port_b_in,
    output  logic   [7:0]   port_b_out,
    output  logic           port_b_io,
    input   logic   [7:0]   port_c_in,
    output  logic   [7:0]   port_c_out,
    output  logic   [7:0]   port_c_io,
    input   logic           ps2_clock,
    input   logic           ps2_data,
    input   logic           enable_tvga,
    input   logic           video_clock,    // 25MHz
    input   logic           video_reset,
    output  logic           video_h_sync,
    output  logic           video_v_sync,
    output  logic   [3:0]   video_r,
    output  logic   [3:0]   video_g,
    output  logic   [3:0]   video_b
);
    //
    // chip select
    //
    logic   [7:0]   chip_select_n;

    always_comb begin
        if (~address_enable_n & ~address[9] & ~address[8]) begin
            casez (address[7:5])
                3'b000:  chip_select_n = 8'b11111110;
                3'b001:  chip_select_n = 8'b11111101;
                3'b010:  chip_select_n = 8'b11111011;
                3'b011:  chip_select_n = 8'b11110111;
                3'b100:  chip_select_n = 8'b11101111;
                3'b101:  chip_select_n = 8'b11011111;
                3'b110:  chip_select_n = 8'b10111111;
                3'b111:  chip_select_n = 8'b01111111;
                default: chip_select_n = 8'b11111111;
            endcase
        end
        else begin
            chip_select_n = 8'b11111111;
        end
    end

    assign  dma_chip_select_n       = chip_select_n[0];
    wire    interrupt_chip_select_n = chip_select_n[1];
    wire    timer_chip_select_n     = chip_select_n[2];
    wire    ppi_chip_select_n       = chip_select_n[3];
    assign  dma_page_chip_select_n  = chip_select_n[4];

    wire    tvga_chip_select_n      = ~(enable_tvga & (address[19:14] == 6'b1011_10));

    //
    // 8259
    //
    logic           timer_interrupt;
    logic           keybord_interrupt;
    logic   [7:0]   interrupt_data_bus_out;

    KF8259 u_KF8259 (
        // Bus
        .clock                      (clock),
        .reset                      (reset),
        .chip_select_n              (interrupt_chip_select_n),
        .read_enable_n              (io_read_n),
        .write_enable_n             (io_write_n),
        .address                    (address[0]),
        .data_bus_in                (internal_data_bus),
        .data_bus_out               (interrupt_data_bus_out),

        // I/O
        .cascade_in                 (3'b000),
        //.cascade_out                (),
        //.cascade_io                 (),
        .slave_program_n            (1'b1),
        //.buffer_enable              (),
        //.slave_program_or_enable_buffer     (),
        .interrupt_acknowledge_n    (interrupt_acknowledge_n),
        .interrupt_to_cpu           (interrupt_to_cpu),
        .interrupt_request          ({interrupt_request[7:2],
                                        keybord_interrupt, timer_interrupt})
    );

    //
    // 8253
    //
    logic   timer_clock;
    always_ff @(negedge peripheral_clock, posedge reset) begin
        if (reset)
            timer_clock <= 1'b0;
        else
            timer_clock <= ~timer_clock;
    end

    logic   [7:0]   timer_data_bus_out;

    wire    tim2gatespk = port_b_out[0] & ~port_b_io;
    wire    spkdata     = port_b_out[1] & ~port_b_io;

    KF8253 u_KF8253 (
        // Bus
        .clock                      (clock),
        .reset                      (reset),
        .chip_select_n              (timer_chip_select_n),
        .read_enable_n              (io_read_n),
        .write_enable_n             (io_write_n),
        .address                    (address[1:0]),
        .data_bus_in                (internal_data_bus),
        .data_bus_out               (timer_data_bus_out),

        // I/O
        .counter_0_clock            (timer_clock),
        .counter_0_gate             (1'b1),
        .counter_0_out              (timer_counter_out[0]),
        .counter_1_clock            (timer_clock),
        .counter_1_gate             (1'b1),
        .counter_1_out              (timer_counter_out[1]),
        .counter_2_clock            (timer_clock),
        .counter_2_gate             (tim2gatespk),
        .counter_2_out              (timer_counter_out[2])
    );

    assign  timer_interrupt = timer_counter_out[0];
    assign  speaker_out     = timer_counter_out[2] & spkdata;

    //
    // 8255
    //
    logic   [7:0]   ppi_data_bus_out;
    logic   [7:0]   port_a_in;

    KF8255 u_KF8255 (
        // Bus
        .clock                      (clock),
        .reset                      (reset),
        .chip_select_n              (ppi_chip_select_n),
        .read_enable_n              (io_read_n),
        .write_enable_n             (io_write_n),
        .address                    (address[1:0]),
        .data_bus_in                (internal_data_bus),
        .data_bus_out               (ppi_data_bus_out),

        // I/O
        .port_a_in                  (port_a_in),
        .port_a_out                 (port_a_out),
        .port_a_io                  (port_a_io),
        .port_b_in                  (port_b_in),
        .port_b_out                 (port_b_out),
        .port_b_io                  (port_b_io),
        .port_c_in                  (port_c_in),
        .port_c_out                 (port_c_out),
        .port_c_io                  (port_c_io)
    );

    //
    // KFPS2KB
    //
    KFPS2KB u_KFPS2KB (
        // Bus
        .clock                      (peripheral_clock),
        .reset                      (reset),

        // PS/2 I/O
        .device_clock               (ps2_clock),
        .device_data                (ps2_data),

        // I/O
        .irq                        (keybord_interrupt),
        .keycode                    (port_a_in),
        .clear_keycode              (port_b_out[7])
    );

    //
    // KFTVGA
    //
    logic   [7:0]   tvga_data_bus_out;

    KFTVGA u_KFTVGA (
        // Bus
        .clock                      (clock),
        .reset                      (reset),
        .chip_select_n              (tvga_chip_select_n),
        .read_enable_n              (memory_read_n),
        .write_enable_n             (memory_write_n),
        .address                    (address[13:0]),
        .data_bus_in                (internal_data_bus),
        .data_bus_out               (tvga_data_bus_out),

        // I/O
        .video_clock                (video_clock),
        .video_reset                (video_reset),
        .video_h_sync               (video_h_sync),
        .video_v_sync               (video_v_sync),
        .video_r                    (video_r),
        .video_g                    (video_g),
        .video_b                    (video_b)
    );

    //
    // data_bus_out
    //
    always_comb begin
        if (~interrupt_acknowledge_n) begin
            data_bus_out_from_chipset = 1'b1;
            data_bus_out = interrupt_data_bus_out;
        end
        else if ((~interrupt_chip_select_n) && (~io_read_n)) begin
            data_bus_out_from_chipset = 1'b1;
            data_bus_out = interrupt_data_bus_out;
        end
        else if ((~timer_chip_select_n) && (~io_read_n)) begin
            data_bus_out_from_chipset = 1'b1;
            data_bus_out = timer_data_bus_out;
        end
        else if ((~ppi_chip_select_n) && (~io_read_n)) begin
            data_bus_out_from_chipset = 1'b1;
            data_bus_out = ppi_data_bus_out;
        end
        else if ((~tvga_chip_select_n) && (~memory_read_n)) begin
            data_bus_out_from_chipset = 1'b1;
            data_bus_out = tvga_data_bus_out;
        end
        else if ((~io_read_n) && (~address_enable_n)) begin
            data_bus_out_from_chipset = 1'b1;
            data_bus_out = 8'hFF;
		end
        else begin
            data_bus_out_from_chipset = 1'b0;
            data_bus_out = 8'b00000000;
        end
    end

endmodule

