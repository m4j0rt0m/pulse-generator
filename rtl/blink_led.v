/* **********************************************************************************************************
 *
 * Module:      Blinking led w/ step control
 * File:        blink_led.v
 * Author:      Abraham J. Ruiz R. (github.com/m4j0rt0m)
 * Release:     1.0 - First version
 *
 * **********************************************************************************************************
 *
 * Parameters:
 *  CLK_FREQ    - Clock frequency (Hz)
 *  FREQ_STEPS  - Amount of steps between the minimum and maximum frequency
 *  MAX_FREQ    - Maximum frecuency
 *  MIN_FREQ    - Minimum frecuency
 *  SCALE_DIV   - Frecuency divider
 *                  e.g. Freq=1Hz with Div=100 => Actual Freq=0.01Hz (One cycle every 100 seconds)
 *
 * **********************************************************************************************************
 *
 * Description: The output LED will blink with a frequency set with the module's parameters and controlled
 *              with the freq step control.
 *              The maximum output frequency of the LED (excluding the physical constraints) is "CLK_FREQ/2".
 *              The minimum output frequency of the LED is "MIN_FREQ / SCALE_DIV".
 *
 * **********************************************************************************************************
 *
 * The frequency established for every step is calculated as follows:
 *  diff_freq   = MAX_FREQ - MIN_FREQ
 *  step_freq   = diff_freq / FREQ_STEPS
 *  actual_freq = MIN_FREQ + (step * step_freq)
 *
 *  e.g.: MAX_FREQ=1000, MIN_FREQ=10, FREQ_STEPS=5
 *    diff_freq = 990
 *    step_freq = 198
 *      actual_freq[0] = 10 + (0 * 198) = 10 Hz
 *      actual_freq[1] = 10 + (1 * 198) = 208 Hz
 *      actual_freq[2] = 10 + (2 * 198) = 406 Hz
 *      actual_freq[3] = 10 + (3 * 198) = 604 Hz
 *      actual_freq[4] = 10 + (4 * 198) = 802 Hz
 *      actual_freq[5] = 10 + (5 * 198) = 1000 Hz
 *
 *  e.g.: MAX_FREQ=50, MIN_FREQ=2, FREQ_STEPS=4
 *    diff_freq = 48
 *    step_freq = 12
 *      actual_freq[0] = 2 + (0 * 12) = 2 Hz
 *      actual_freq[1] = 2 + (1 * 12) = 14 Hz
 *      actual_freq[2] = 2 + (2 * 12) = 26 Hz
 *      actual_freq[3] = 2 + (3 * 12) = 38 Hz
 *      actual_freq[4] = 2 + (4 * 12) = 50 Hz
 *
 *  e.g.: MAX_FREQ=10, MIN_FREQ=5, FREQ_STEPS=1
 *    diff_freq = 5
 *    step_freq = 5
 *      actual_freq[0] = 5 + (0 * 5) = 5 Hz
 *      actual_freq[1] = 5 + (1 * 5) = 10 Hz
 *
 * **********************************************************************************************************
 *
 * The counter limit is the relation between the CLK_FREQ, actual_freq and SCALE_DIV (flip trigger):
 *  counter_limit = SCALE_DIV * (CLK_FREQ / (2 * actual_freq))
 *
 *  e.g.: CLK_FREQ=100, actual_freq=50, SCALE_DIV=1
 *    output_freq   = (50 / 1) = 50 Hz
 *    counter_limit = 1 * (100 / (2 * 50)) = 1 clock cycles for every flip
 *
 *  e.g.: CLK_FREQ=100, actual_freq=50, SCALE_DIV=10
 *    output_freq   = (50 / 10) = 5 Hz
 *    counter_limit = 10 * (100 / (2 * 50)) = 10 clock cycles for every flip
 *
 *  e.g.: CLK_FREQ=50MHz, actual_freq=100, SCALE_DIV=10
 *    output_freq   = (100 / 10) = 10 Hz
 *    counter_limit = 100 * (50000000 / (2 * 100)) = 2500000 clock cycles for every flips
 *
 * **********************************************************************************************************
 */

`default_nettype none

module blink_led
# (
    parameter CLK_FREQ    = 50000000,
    parameter FREQ_STEPS  = 10,
    parameter MAX_FREQ    = 100,
    parameter MIN_FREQ    = 1,
    parameter SCALE_DIV   = 10
  )
(/*AUTOARG*/
   // Outputs
   led_o,
   // Inputs
   clk_i, arstn_i, freq_up_i, freq_dwn_i
   );

  /* local parameters */
  localparam COUNTER_WIDTH = $clog2(SCALE_DIV * (CLK_FREQ / (2 * MIN_FREQ)));
  localparam PTR_WIDTH     = $clog2(FREQ_STEPS + 1);

  /* clock and reset - port*/
  input   wire  clk_i;
  input   wire  arstn_i;

  /* freq step control - port */
  input   wire  freq_up_i;
  input   wire  freq_dwn_i;

  /* led output */
  output  reg   led_o;

  /* regs n wires declaration */
  reg  [COUNTER_WIDTH-1:0] counter;
  wire [COUNTER_WIDTH-1:0] nxt_counter;
  reg  [COUNTER_WIDTH-1:0] limit;
  reg  [PTR_WIDTH-1:0]     limit_ptr;
  wire [COUNTER_WIDTH-1:0] limit_array [FREQ_STEPS:0];
  wire                     change;
  wire [PTR_WIDTH-1:0]     ptr_up;
  wire [PTR_WIDTH-1:0]     ptr_dwn;

  /* integers and genvars */
  genvar I;

  /* counter limit calculation (at synthesis time) */
  generate
    for(I=0; I<=FREQ_STEPS; I=I+1) begin: limit_calc_gen
      assign limit_array[I] = SCALE_DIV * (CLK_FREQ / (2 * (MIN_FREQ + ((I * (MAX_FREQ - MIN_FREQ)) / FREQ_STEPS))));
    end
  endgenerate

  /* the "change" wire will set to "1" if there is only one control set to "1" */
  assign change = freq_up_i ^ freq_dwn_i; //..(0 xor 0 = 0) (0 xor 1 = 1) (1 xor 0 = 1) (1 xor 1 = 0)

  /* counter limit pointers UP and DWN assignments */
  assign ptr_up  = (limit_ptr == (FREQ_STEPS)) ? limit_ptr : limit_ptr + {{(PTR_WIDTH-1){1'b0}},1'b1};
  assign ptr_dwn = (limit_ptr == 0) ? limit_ptr : limit_ptr - {{(PTR_WIDTH-1){1'b0}},1'b1};

  /* next counter value */
  assign nxt_counter = counter + {{(COUNTER_WIDTH-1){1'b0}},1'b1};

  /* freq step control logic */
  always @ (posedge clk_i, negedge arstn_i) begin
    if(~arstn_i) begin
      limit     <= limit_array[0];
      limit_ptr <= {PTR_WIDTH{1'b0}};
    end
    else begin
      if(change) begin //..a single button has been pushed
        if(freq_up_i) begin //..freq_up
          limit     <= limit_array[ptr_up];
          limit_ptr <= ptr_up;
        end
        else begin //..freq_down
          limit     <= limit_array[ptr_dwn];
          limit_ptr <= ptr_dwn;
        end
      end
    end
  end

  /* blink led logic */
  always @ (posedge clk_i, negedge arstn_i) begin
    if(~arstn_i) begin
      counter <= {COUNTER_WIDTH{1'b0}};
      led_o   <= 1'b0;
    end
    else begin
      if(nxt_counter >= limit) begin
        counter <= {COUNTER_WIDTH{1'b0}};
        led_o   <= ~led_o;
      end
      else
        counter <= nxt_counter;
    end
  end

endmodule // blink_led

`default_nettype wire
