/* **********************************************************************************************************
 *
 * Module:      Frequency calculator from period time
 * File:        freq_calc.v
 * Author:      Abraham J. Ruiz R. (github.com/m4j0rt0m)
 * Release:     1.0 - First version
 *
 * **********************************************************************************************************
 *
 * Parameters:
 *  MAX_FREQ    - Maximum input frequency (Hz)
 *
 * **********************************************************************************************************
 *
 * Description: Calculates the frequency "freq_o" from the "signal_i" input, depending on the `timescale
 *                f(x) = cycles_per_second / period_time
 *
 * **********************************************************************************************************
 */

`timescale 1ns/1ns

module freq_calc
# (
    parameter MAX_FREQ = 1000000
  )
(/*AUTOARG*/
   // Outputs
   freq_o,
   // Inputs
   signal_i, arstn_i
   );

  /* local parameters */
  localparam FREQ_WIDTH = $clog2(MAX_FREQ + 1);

  /* clock and reset */
  input   wire  signal_i;
  input   wire  arstn_i;

  /* frequency value */
  output  wire  [FREQ_WIDTH-1:0] freq_o;

  /* time variables */
  time period_time;
  time last_time;

  /* period register */
  always @ (posedge signal_i, negedge arstn_i) begin
    if(~arstn_i) begin
      period_time <= 0;
      last_time   <= 0;
    end
    else begin
      period_time <= $stime - last_time;
      last_time   <= $stime;
    end
  end

  /* frequency */
  assign freq_o = ((period_time <= 0) | (period_time == last_time)) ? {FREQ_WIDTH{1'b0}} : 1000000000 / period_time;

endmodule // freq_calc
