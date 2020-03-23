/* **********************************************************************************************************
 *
 * Module:      Testbench: Blinking led w/ step control
 * File:        blink_led_tb.v
 * Author:      Abraham J. Ruiz R. (github.com/m4j0rt0m)
 * Release:     1.0 - First version
 *
 * **********************************************************************************************************
 *
 * Simulation Parameters:
 *  CLK_FREQ    - Clock frequency (Hz)
 *  FREQ_STEPS  - Amount of steps between the minimum and maximum frequency
 *  MAX_FREQ    - Maximum frecuency
 *  MIN_FREQ    - Minimum frecuency
 *  SCALE_DIV   - Frecuency divider
 *                  e.g. Freq=1Hz with Div=100 => Actual Freq=0.01Hz (One cycle every 100 seconds)
 *  SIM_PULSES  - Amount of LED's cycles before changing up/down its frequency
 *  SIM_CYCLES  - Number of sweeps (MIN_FREQ -> MAX_FREQ -> MIN_FREQ) for the simulation
 *  INT_CYCLES  - Simulation TIME_OUT value
 *
 * **********************************************************************************************************
 */

`timescale 1ns/1ns
`default_nettype none

module blink_led_tb ();

  /* dut parameters */
  localparam CLK_FREQ    = 50000000;
  localparam FREQ_STEPS  = 50;
  localparam MAX_FREQ    = 100000;
  localparam MIN_FREQ    = 1000;
  localparam SCALE_DIV   = 3;

  /* sim parameters */
  localparam SIM_PULSES       = 2;
  localparam SIM_CYCLES       = 3;
  localparam INT_CYCLES       = 200000000;

  /* some widths params */
  localparam SIM_PULSES_WIDTH = $clog2(SIM_PULSES + 1);
  localparam COMPLETED_CYCLES = $clog2(SIM_CYCLES + 1);
  localparam FREQ_WIDTH       = $clog2(CLK_FREQ + 1);
  localparam PTR_WIDTH        = $clog2(FREQ_STEPS + 1);

  /* some states definitions */
  `define _DIR_UP_    1'b0
  `define _DIR_DOWN_  1'b1
  `define _LED_OFF_   1'b0
  `define _LED_ON_    1'b1

  /* clock and reset - port*/
  reg  clk_i;
  reg  arstn_i;

  /* freq step control - port */
  reg  freq_up_i;
  reg  freq_dwn_i;

  /* led output */
  wire led_o;

  /* sim regs and wires */
  reg   [SIM_PULSES_WIDTH-1:0]  sim_counter;
  reg   [COMPLETED_CYCLES-1:0]  completed_cycles;
  reg   [PTR_WIDTH-1:0]         step_count;
  reg                           step_dir;
  reg                           state_led;
  wire  [FREQ_WIDTH-1:0]        freq_clk;
  wire  [FREQ_WIDTH-1:0]        freq_led;

  /* integers and genvars */
  integer i;

  /* clock simulation */
  always
    #10 clk_i = ~clk_i;

  /* reset simulation */
  always
    #100 arstn_i = 1'b1;

  /* variable initialization */
  initial begin
    clk_i = 1'b0;
    arstn_i = 1'b0;
    freq_up_i = 1'b0;
    freq_dwn_i = 1'b0;
  end

  /* simulation */
  always @ (posedge clk_i, negedge arstn_i) begin
    if(~arstn_i) begin
      sim_counter       = 0;
      freq_up_i         = 0;
      freq_dwn_i        = 0;
      step_count        = 0;
      completed_cycles  = 0;
      step_dir          = `_DIR_UP_;
      state_led         = `_LED_OFF_;
    end
    else begin
      case(state_led)
        `_LED_OFF_: begin
          if(led_o) begin //..led has turned on
            if(sim_counter == SIM_PULSES) begin
              case(step_dir)
                `_DIR_UP_:   freq_up_i   = 1;
                `_DIR_DOWN_: freq_dwn_i  = 1;
              endcase
              step_count  = step_count + 1;
              sim_counter = 0;
            end
            else
              sim_counter = sim_counter + 1;
            state_led = `_LED_ON_;
          end
        end
        `_LED_ON_: begin
          freq_up_i   = 0;
          freq_dwn_i  = 0;
          if(~led_o) begin //..led has turned off
            if(step_count == FREQ_STEPS) begin
              case(step_dir)
                `_DIR_UP_:   step_dir = `_DIR_DOWN_;
                `_DIR_DOWN_: begin
                  step_dir         = `_DIR_UP_;
                  completed_cycles = completed_cycles + 1;
                end
              endcase
              step_count  = 0;
            end
            if(completed_cycles == SIM_CYCLES) begin
              $display("\n  ************************* [ Simulation   END    ] *************************\n");
              $finish;
            end
            state_led = `_LED_OFF_;
          end
        end
      endcase
    end
  end

  /* dut */
  blink_led
    # (
        .CLK_FREQ   (CLK_FREQ),
        .FREQ_STEPS (FREQ_STEPS),
        .MAX_FREQ   (MAX_FREQ),
        .MIN_FREQ   (MIN_FREQ),
        .SCALE_DIV  (SCALE_DIV)
      )
    dut (
      .clk_i      (clk_i),
      .arstn_i    (arstn_i),
      .freq_up_i  (freq_up_i),
      .freq_dwn_i (freq_dwn_i),
      .led_o      (led_o)
    );

  /* freq monitors (clock and led) */
  defparam freq_monitor_clk.MAX_FREQ = CLK_FREQ;
  defparam freq_monitor_led.MAX_FREQ = CLK_FREQ;
  freq_calc
    freq_monitor_clk (
      .signal_i (clk_i),
      .arstn_i  (arstn_i),
      .freq_o   (freq_clk)
    ),
    freq_monitor_led (
      .signal_i (led_o),
      .arstn_i  (arstn_i),
      .freq_o   (freq_led)
    );

  /* sim log */
  initial begin
    $dumpfile("blink_led.vcd");
    $dumpvars();
    for(i=0; i<=FREQ_STEPS; i=i+1) $dumpvars(1, dut.limit_array[i]);

    $display("\n  ************************* [ Simulation  START   ] *************************\n");
    #INT_CYCLES;
    $display("\n  ************************* [ Simulation TIME OUT ] *************************\n");
    $finish;
  end

  /* display info */
  always @ (freq_led) begin
    $display("[Time @ %d] : [Clock @ %d Hz] : [Step in %d] : [LED @ %d Hz]", $stime,
                                                                       freq_clk,
                                                                       dut.limit_ptr,
                                                                       freq_led);
  end

endmodule // blink_led_tb

`default_nettype wire
