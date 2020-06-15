/* **********************************************************************************************************
 *
 * Module:      Sweep bit transition between limits
 * File:        sweep_transition.v
 * Author:      Abraham J. Ruiz R. (github.com/m4j0rt0m)
 * Release:     1.0 - First version
 *
 * **********************************************************************************************************
 *
 * Parameters:
 *  WIDTH - Bit mask width for the transition
 *
 * **********************************************************************************************************
 *
 * Description: Generates the mask bits for the sweep effect
 *
 * **********************************************************************************************************
 */

`default_nettype none

module sweep_transition
# (
    parameter WIDTH = 4
  )
(/*AUTOARG*/
   // Outputs
   mask_o,
   // Inputs
   clk_i, arstn_i, en_i, tick_i
   );

  /* local parameters */
  localparam BIT_PTR  = $clog2(WIDTH);

  /* clock and reset - port */
  input   wire              clk_i;
  input   wire              arstn_i;

  /* operation control - port */
  input   wire              en_i;
  input   wire              tick_i;

  /* mask bits - port */
  output  wire  [WIDTH-1:0] mask_o;

  /* regs and wires */
  reg   [WIDTH-1:0]     mask_int;
  wire  [WIDTH-1:0]     mask_nxt;
  reg                   mask_trans;
  wire                  mask_limit;
  wire  [BIT_PTR-1:0]   mask_ptr_prev [WIDTH-1:0];
  wire  [BIT_PTR-1:0]   mask_ptr_nxt  [WIDTH-1:0];

  /* fsm declaration */
  reg   [2:0] sweep_state;
  localparam StateRst  = 3'b000;
  localparam StateRun  = 3'b011;
  localparam StateCont = 3'b101;

  /* genvars */
  genvar I;

  /* sweep pointer assignments - mask */
  /*
   * transition-a: [000 --> 001] [001 --> 010] [010 --> 011] [011 --> 100] [100 --> 101] [101 --> 110] [110 --> 111]
   * transition-b: [111 --> 110] [110 --> 101] [101 --> 100] [100 --> 011] [011 --> 010] [010 --> 001] [001 --> 000]
   */
  generate
    for(I = 0; I < WIDTH; I = I + 1) begin: mask_transitions_gen
      assign mask_ptr_nxt[I]  = (I+1)%WIDTH;
      assign mask_ptr_prev[I] = (I+WIDTH-1);
      assign mask_nxt[I]      = mask_trans ? mask_int[mask_ptr_nxt[I]] : mask_int[mask_ptr_prev[I]];
    end
    assign mask_limit = mask_trans ? mask_int[0] : mask_int[WIDTH-1];
  endgenerate

  /* sweep control - mask */
  always @ (posedge clk_i, negedge arstn_i) begin
    if(~arstn_i) begin
      mask_int    <= {WIDTH{1'b0}};
      mask_trans  <= 1'b0;
      sweep_state <= StateRst;
    end
    else begin
      if(~en_i) begin
        mask_int    <= {WIDTH{1'b0}};
        mask_trans  <= 1'b0;
        sweep_state <= StateRst;
      end
      else begin
        case(sweep_state)
          StateRst: begin
            mask_int    <= {{(WIDTH-1){1'b0}},1'b1};
            mask_trans  <= 1'b0;
            sweep_state <= StateRun;
          end
          StateRun: begin
            if(tick_i) begin
              mask_trans  <= mask_limit ? ~mask_trans : mask_trans;
              sweep_state <= StateCont;
            end
          end
          StateCont: begin
            if(~tick_i) begin
              mask_int    <= mask_nxt;
              sweep_state <= StateRun;
            end
          end
          default: begin
            mask_int    <= {WIDTH{1'b0}};
            mask_trans  <= 1'b0;
            sweep_state <= StateRst;
          end
        endcase
      end
    end
  end

  /* output assignment */
  assign mask_o = mask_int;

endmodule // sweep_transition
