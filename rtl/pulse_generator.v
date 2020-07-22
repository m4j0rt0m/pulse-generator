/* **********************************************************************************************************
 *
 * Module:      Pulse Generator w/ step control
 * File:        pulse_generator.v
 * Author:      Abraham J. Ruiz R. (github.com/m4j0rt0m)
 * Release:     1.0 - First version
 *              1.1 - Added initial step selector parameter, enable and pause control
 *              1.2 - Renamed to Frequency Generator
 *              1.3 - Added exponential mode
 *              1.4 - [Linear / Exponential / PWM] mode selector
 *              1.5 - Renamed to Pulse Generator
 *
 * **********************************************************************************************************
 *
 * Parameters:
 *  CLK_FREQ    - Clock frequency (Hz)
 *  FREQ_STEPS  - Amount of steps between the minimum and maximum frequency
 *  MAX_FREQ    - Maximum frecuency
 *  MIN_FREQ    - Minimum frecuency (Linear mode)
 *  MODE_DIV    - [Linear=0] , [Exponential=1] or [PWM=2]
 *  SCALE_DIV   - Frecuency divider (linear / exponential / pwm)
 *                  When linear: Frequency is divided by SCALE_DIV
 *                    e.g. Freq=1Hz with SCALE_DIV=100 => Actual Freq=0.01Hz (One cycle every 100 seconds)
 *                  When exponential: Frequency is exponentially divided by SCALE_DIV
 *                    e.g. freq[3]=10KHz with SCALE_DIV=10 => freq[2]=1KHz freq[1]=100Hz and freq[0]=10Hz
 *  PWM_FREQ    - Pulse frequency to be used in PWM mode
 *  PWM_H_DUTY  - Maximum duty cycle in PWM mode (%)
 *  PWM_L_DUTY  - Minimum duty cycle in PWM mode (%)
 *  INIT_STEP   - Initial step selector from the "n" FREQ_STEPS
 *
 * **********************************************************************************************************
 *
 * Description: The output will generate a pulse with a frequency configured with the module's parameters and controlled
 *              with the freq step control and operation mode.
 *              The maximum output frequency of the oscillator (excluding the physical constraints) is "CLK_FREQ/2".
 *              The minimum output frequency of the oscillator is:
 *                MIN_FREQ / SCALE_DIV
 *              In PWM mode, the output frequency is defined by:
 *                PWM_FREQ / SCALE_DIV
 *
 * **********************************************************************************************************
 *
 * The frequency established for every step is calculated as follows:
 *  [linear]:
 *    diff_freq   = MAX_FREQ - MIN_FREQ
 *    step_freq   = diff_freq / FREQ_STEPS
 *    actual_freq = MIN_FREQ + (#step * step_freq)
 *
 *    e.g.: [LINEAR] MAX_FREQ=50, MIN_FREQ=2, FREQ_STEPS=4
 *      diff_freq = 48
 *      step_freq = 12
 *        actual_freq[0] = 2 + (0 * 12) = 2 Hz
 *        actual_freq[1] = 2 + (1 * 12) = 14 Hz
 *        actual_freq[2] = 2 + (2 * 12) = 26 Hz
 *        actual_freq[3] = 2 + (3 * 12) = 38 Hz
 *        actual_freq[4] = 2 + (4 * 12) = 50 Hz
 *
 *  [exponential]:
 *    step_freq   = 1 / SCALE_DIV
 *    actual_freq = MAX_FREQ / (SCALE_DIV ** (FREQ_STEPS - #step))
 *
 *    e.g.: [EXPONENTIAL] MAX_FREQ=10000, FREQ_STEPS=4, SCALE_DIV=5
 *      step_freq = 1/5
 *        actual_freq[0] = 10000 / (5**(4-0)) = 10000 / (5**4) = 10000 / 625 = 16 Hz
 *        actual_freq[1] = 10000 / (5**(4-1)) = 10000 / (5**3) = 10000 / 125 = 80 Hz
 *        actual_freq[2] = 10000 / (5**(4-2)) = 10000 / (5**2) = 10000 / 25  = 400 Hz
 *        actual_freq[3] = 10000 / (5**(4-3)) = 10000 / (5**1) = 10000 / 5   = 2000 Hz
 *        actual_freq[4] = 10000 / (5**(4-4)) = 10000 / (5**0) = 10000 / 1   = 10000 Hz
 *
 *  [pwm]:
 *    h_duty_freq = (PWM_FREQ * PWM_H_DUTY) / 100
 *    l_duty_freq = (PWM_FREQ * PWM_L_DUTY) / 100
 *    diff_freq   = (PWM_FREQ * (PWM_H_DUTY - PWM_L_DUTY)) / 100
 *    actual_freq = PWM_FREQ / SCALE_DIV
 *    step_freq   = diff_freq / FREQ_STEPS = (PWM_FREQ * (PWM_H_DUTY - PWM_L_DUTY)) / (100 * FREQ_STEPS)
 *
 * **********************************************************************************************************
 *
 * The counter limit is the relation between the CLK_FREQ, actual_freq and SCALE_DIV (flip trigger):
 *  [linear]:
 *    counter_limit   = CLK_FREQ / (2 * actual_freq) --> (multiplied by SCALE_DIV)
 *  [exponential]:
 *    counter_limit   = CLK_FREQ / (2 * actual_freq)
 *  [pwm]:
 *    total_count     = CLK_FREQ / actual_freq = (SCALE_DIV * CLK_FREQ) / PWM_FREQ
 *    start_count     = (100 * CLK_FREQ) / (PWM_FREQ * PWM_L_DUTY)
 *    step_count_incr = CLK_FREQ / step_freq = (100 * CLK_FREQ * FREQ_STEPS) / (PWM_FREQ * (PWM_H_DUTY - PWM_L_DUTY))
 *    counter_limit_h = start_count + (#step * step_count_incr)
 *    counter_limit_l = total_count - counter_limit_h
 *
 * **********************************************************************************************************
 */

`default_nettype none

module pulse_generator
# (
    parameter CLK_FREQ    = 50000000,
    parameter FREQ_STEPS  = 10,
    parameter MAX_FREQ    = 100,
    parameter MIN_FREQ    = 1,
    parameter SCALE_DIV   = 10,
    parameter PWM_FREQ    = 1000,
    parameter PWM_H_DUTY  = 80,
    parameter PWM_L_DUTY  = 20,
    parameter INIT_STEP   = 0
  )
(/*AUTOARG*/
   // Outputs
   pulse_o,
   // Inputs
   clk_i, arstn_i, en_i, pause_i, mask_i, mode_i, set_i, select_i,
   step_up_i, step_dwn_i
   );

  /* some defines */
  `ifndef _MODES_OP_
  `define _MODES_OP_
    `define _NUM_MODES_   3
    `define _LINEAR_      0
    `define _EXPONENTIAL_ 1
    `define _PWM_         2
  `endif

  /* local parameters */
  localparam MINIMUM_FREQ         = MIN_FREQ;
  localparam MAXIMUM_COUNT        = CLK_FREQ / (2 * MINIMUM_FREQ);
  localparam COUNTER_WIDTH        = $clog2((SCALE_DIV * MAXIMUM_COUNT) + 1);
  localparam PTR_WIDTH            = $clog2(FREQ_STEPS + 1);
  localparam FREQ_PER_STEP        = (MAX_FREQ - MIN_FREQ) / FREQ_STEPS;
  localparam DUTY_FREQ_STEP       = (PWM_FREQ * (PWM_H_DUTY - PWM_L_DUTY)) / (100 * FREQ_STEPS);
  localparam FREQ_WIDTH           = $clog2(MAX_FREQ + 1);
  localparam MODE_SEL             = $clog2(`_NUM_MODES_ + 1);
  localparam PWM_TOTAL_COUNT      = (SCALE_DIV * CLK_FREQ) / PWM_FREQ;
  localparam PWM_START_COUNT      = (PWM_L_DUTY * PWM_TOTAL_COUNT) / 100;
  localparam PWM_STEP_COUNT_INCR  = (DUTY_FREQ_STEP * PWM_TOTAL_COUNT) / PWM_FREQ;

  /* clock and reset - port*/
  input   wire                  clk_i;
  input   wire                  arstn_i;

  /* operation control - port */
  input   wire                  en_i;
  input   wire                  pause_i;
  input   wire                  mask_i;
  input   wire  [MODE_SEL-1:0]  mode_i;

  /* freq setup control - port */
  input   wire                  set_i;
  input   wire  [PTR_WIDTH-1:0] select_i;

  /* freq step control - port */
  input   wire                  step_up_i;
  input   wire                  step_dwn_i;

  /* oscillator output */
  output  wire                  pulse_o;

  /* regs n wires declaration */
  wire                     soft_reset;
  reg                      pulse_int;
  reg  [COUNTER_WIDTH-1:0] counter;
  wire [COUNTER_WIDTH-1:0] nxt_counter;
  reg  [COUNTER_WIDTH-1:0] limit;
  reg  [COUNTER_WIDTH-1:0] limit_pwm;
  wire [COUNTER_WIDTH-1:0] limit_mode;
  reg  [PTR_WIDTH-1:0]     limit_ptr;
  wire [COUNTER_WIDTH-1:0] limit_array_linear [FREQ_STEPS:0];
  wire [COUNTER_WIDTH-1:0] limit_array_exp    [FREQ_STEPS:0];
  wire [COUNTER_WIDTH-1:0] limit_array_pwm_h  [FREQ_STEPS:0];
  wire [COUNTER_WIDTH-1:0] limit_array_pwm_l  [FREQ_STEPS:0];
  reg                      pwm_state;
  `ifdef SIMULATION
  wire [FREQ_WIDTH-1:0]    freq_array_linear  [FREQ_STEPS:0];
  wire [FREQ_WIDTH-1:0]    freq_array_exp     [FREQ_STEPS:0];
  wire [FREQ_WIDTH-1:0]    freq_array_pwm     [FREQ_STEPS:0];
  `endif
  wire                     change;
  wire [PTR_WIDTH-1:0]     ptr_up;
  wire [PTR_WIDTH-1:0]     ptr_dwn;

  /* integers and genvars */
  genvar I;

  /* counter limit calculation (at synthesis time) */
  generate
    for(I=0; I<=FREQ_STEPS; I=I+1) begin: limit_calc_gen
      `ifdef SIMULATION
      assign freq_array_linear[I] = (MIN_FREQ + (I * FREQ_PER_STEP)) / SCALE_DIV;
      assign freq_array_exp[I] = MAX_FREQ / (SCALE_DIV ** (FREQ_STEPS - I));
      assign freq_array_pwm[I] = PWM_FREQ / SCALE_DIV;
      `endif
      //..linear
      assign limit_array_linear[I] = SCALE_DIV * (CLK_FREQ / (2 * (MIN_FREQ + (I * FREQ_PER_STEP))));
      //..exponential
      assign limit_array_exp[I] = CLK_FREQ / (2 * (MAX_FREQ / (SCALE_DIV ** (FREQ_STEPS - I))));
      //..pwm
      assign limit_array_pwm_h[I] = PWM_START_COUNT[COUNTER_WIDTH-1:0] + (I * PWM_STEP_COUNT_INCR[COUNTER_WIDTH-1:0]);
      assign limit_array_pwm_l[I] = PWM_TOTAL_COUNT[COUNTER_WIDTH-1:0] - limit_array_pwm_h[I];
    end
  endgenerate

  /* soft reset, the logic must be cleared everytime there is a frequency change or the logic is disabled */
  assign soft_reset = set_i | ~en_i | change;

  /* the "change" wire will set to "1" if there is only one control set to "1" */
  assign change = step_up_i ^ step_dwn_i; //..(0 xor 0 = 0) (0 xor 1 = 1) (1 xor 0 = 1) (1 xor 1 = 0)

  /* counter limit pointers UP and DWN assignments */
  assign ptr_up  = (limit_ptr == (FREQ_STEPS)) ? limit_ptr : limit_ptr + {{(PTR_WIDTH-1){1'b0}},1'b1};
  assign ptr_dwn = (limit_ptr == 0) ? limit_ptr : limit_ptr - {{(PTR_WIDTH-1){1'b0}},1'b1};

  /* next counter value */
  assign nxt_counter = counter + {{(COUNTER_WIDTH-1){1'b0}},~pause_i};

  /* freq step control logic */
  always @ (posedge clk_i, negedge arstn_i) begin
    if(~arstn_i) begin
      limit     <= limit_array_linear[INIT_STEP];
      limit_pwm <= limit_array_pwm_l[INIT_STEP];
      limit_ptr <= INIT_STEP[PTR_WIDTH-1:0];
    end
    else begin
      if(soft_reset) begin
        if(set_i) begin //..manual frequency setup
          case(mode_i)
            `_LINEAR_:      limit <= limit_array_linear[select_i];
            `_EXPONENTIAL_: limit <= limit_array_exp[select_i];
            `_PWM_: begin
              limit     <= limit_array_pwm_h[select_i];
              limit_pwm <= limit_array_pwm_l[select_i];
            end
            default:        limit <= limit_array_linear[select_i];
          endcase
          limit_ptr <= select_i;
        end
        else if (change) begin //..a single button has been pushed
          if(step_up_i) begin //..freq_up
            case(mode_i)
              `_LINEAR_:      limit <= limit_array_linear[ptr_up];
              `_EXPONENTIAL_: limit <= limit_array_exp[ptr_up];
              `_PWM_: begin
                limit     <= limit_array_pwm_h[ptr_up];
                limit_pwm <= limit_array_pwm_l[ptr_up];
              end
              default:        limit <= limit_array_linear[ptr_up];
            endcase
            limit_ptr <= ptr_up;
          end
          else begin //..freq_down
            case(mode_i)
              `_LINEAR_:      limit <= limit_array_linear[ptr_dwn];
              `_EXPONENTIAL_: limit <= limit_array_exp[ptr_dwn];
              `_PWM_: begin
                limit     <= limit_array_pwm_h[ptr_dwn];
                limit_pwm <= limit_array_pwm_l[ptr_dwn];
              end
              default:        limit <= limit_array_linear[ptr_dwn];
            endcase
            limit_ptr <= ptr_dwn;
          end
        end
        else begin //..disabled logic [en_i == 0]
          case(mode_i)
            `_LINEAR_:      limit <= limit_array_linear[INIT_STEP];
            `_EXPONENTIAL_: limit <= limit_array_exp[INIT_STEP];
            `_PWM_:         limit <= limit_array_pwm_h[INIT_STEP];
            default:        limit <= limit_array_linear[INIT_STEP];
          endcase
          limit_pwm <= limit_array_pwm_l[INIT_STEP];
          limit_ptr <= INIT_STEP[PTR_WIDTH-1:0];
        end
      end
    end
  end

  /* limit selection depending on pulse mode and pwm state */
  assign limit_mode = (mode_i == `_PWM_) ? ~pwm_state ? limit_pwm : limit : limit;

  /* oscillator logic */
  always @ (posedge clk_i, negedge arstn_i) begin
    if(~arstn_i) begin
      counter   <= {COUNTER_WIDTH{1'b0}};
      pulse_int <= 1'b0;
      pwm_state <= 1'b1;
    end
    else begin
      if(soft_reset) begin
        counter   <= {COUNTER_WIDTH{1'b0}};
        pulse_int <= 1'b1;
        pwm_state <= 1'b1;
      end
      else begin
        if(nxt_counter >= limit_mode) begin
          counter   <= {COUNTER_WIDTH{1'b0}};
          pulse_int <= en_i ? ~pulse_int : 1'b0;
          pwm_state <= ~pause_i ^ pwm_state;
        end
        else
          counter   <= nxt_counter;
      end
    end
  end

  /* output assignment */
  assign pulse_o = mask_i & pulse_int;

endmodule // pulse_generator

`default_nettype wire
