/* **********************************************************************************************************
 *
 * Module:      Sweep bit transition between limits
 * File:        sweep_transition.v
 * Author:      Abraham J. Ruiz R. (github.com/m4j0rt0m)
 * Release:     1.0 - First version
 *              1.1 - Start corner selection
 *              1.2 - Added tail control
 *
 * **********************************************************************************************************
 *
 * Parameters:
 *  WIDTH      - Bit mask width for the transition
 *  FREQ_STEPS - Amount of frequency steps that can be selected for each bit
 *  TAIL_WIDTH - Amount of tail bits
 *  START_BIT  - Indicates the starting bit in a reset state
 *  CORNER_SEL - Indicates the starting corner (left or right)
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
    parameter WIDTH       = 4,
    parameter FREQ_STEPS  = 4,
    parameter TAIL_WIDTH  = 4,
    parameter START_BIT   = 0,
    parameter CORNER_SEL  = 1
  )
(/*AUTOARG*/
   // Outputs
   mask_o, set_o, select_o,
   // Inputs
   clk_i, arstn_i, en_i, tick_i
   );

  /* local parameters */
  localparam BIT_PTR          = $clog2(WIDTH);
  localparam SEL_WIDTH        = $clog2(FREQ_STEPS + 1);
  localparam FREQ_SEL_PACKED  = SEL_WIDTH * WIDTH;

  /* clock and reset - port */
  input   wire                        clk_i;
  input   wire                        arstn_i;

  /* operation control - port */
  input   wire                        en_i;
  input   wire                        tick_i;

  /* mask bits and freq selection - port */
  output  wire  [WIDTH-1:0]           mask_o;
  output  wire                        set_o;
  output  wire  [FREQ_SEL_PACKED-1:0] select_o;

  /* regs and wires */
  reg   [WIDTH-1:0]           mask_int      [TAIL_WIDTH-1:0];
  wire  [WIDTH-1:0]           mask_nxt      [TAIL_WIDTH-1:0];
  reg   [TAIL_WIDTH-1:0]      mask_trans;
  wire  [TAIL_WIDTH-1:0]      mask_limit;
  wire  [TAIL_WIDTH-1:0]      mask_first;
  wire  [TAIL_WIDTH-1:0]      mask_first_prev;
  wire  [BIT_PTR-1:0]         mask_ptr_prev [WIDTH-1:0];
  wire  [BIT_PTR-1:0]         mask_ptr_nxt  [WIDTH-1:0];
  wire                        continue_int;
  wire  [TAIL_WIDTH-1:0]      mask_int_t    [WIDTH-1:0];
  wire  [WIDTH-1:0]           freq_mask_en  [TAIL_WIDTH-1:0];
  wire  [FREQ_SEL_PACKED-1:0] freq_sel      [TAIL_WIDTH-1:0];
  wire  [TAIL_WIDTH-1:0]      freq_sel_t    [FREQ_SEL_PACKED-1:0];
  reg   [TAIL_WIDTH-1:0]      set_int;

  /* fsm declaration */
  reg   [4:0] sweep_state [TAIL_WIDTH-1:0];
  localparam StateRst   = 5'b00000;
  localparam StateRun   = 5'b00011;
  localparam StateCont  = 5'b00101;
  localparam StateWait  = 5'b01001;
  localparam StateTrans = 5'b10001;

  /* integers and genvars */
  genvar I, J;

  /* sweep pointer assignments - mask */
  /*
   * transition-a: [000 --> 001] [001 --> 010] [010 --> 011] [011 --> 100] [100 --> 101] [101 --> 110] [110 --> 111]
   * transition-b: [111 --> 110] [110 --> 101] [101 --> 100] [100 --> 011] [011 --> 010] [010 --> 001] [001 --> 000]
   *  tail (4 elements):
   *    -> 0 0 1 2 3 4 0 0
   *    <- 0 4 3 2 1 0 0 0
   */
  generate
    for(I = 0; I < WIDTH; I = I + 1) begin: mask_pointers_gen
      assign mask_ptr_nxt[I]  = (I+1)%WIDTH;
      assign mask_ptr_prev[I] = (I+WIDTH-1);
    end
  endgenerate

  /* next bit transition assignments - mask */
  generate
    for(I = 0; I < TAIL_WIDTH; I = I + 1) begin: mask_transitions_tail_gen
      for(J = 0; J < WIDTH; J = J + 1) begin: mask_transitions_bit_gen
        assign mask_nxt[I][J] = mask_trans[I] ? mask_int[I][mask_ptr_nxt[J]] : mask_int[I][mask_ptr_prev[J]];
      end
    end
  endgenerate

  /* limits and first positions - mask */
  generate
    for(I = 0; I < TAIL_WIDTH; I = I + 1) begin: limit_first_bits_gen
      assign mask_limit[I]  = mask_trans[I] ? mask_int[I][0] : mask_int[I][WIDTH-1];
      assign mask_first[I]  = mask_trans[I] ? mask_int[I][WIDTH-1] : mask_int[I][0];
    end
  endgenerate

  /* prograssion assignments - mask */
  generate
    for(I = 0; I < TAIL_WIDTH; I = I + 1) begin: progression_first_bit_gen
      if(I == 0)
        assign mask_first_prev[I]  = 1'b0;
      else
        assign mask_first_prev[I] = mask_first[I-1];
    end
  endgenerate
  assign continue_int = &mask_limit;

  /* frequency masks-en */
  generate
    for(I = 0; I < TAIL_WIDTH; I = I + 1) begin: freq_mask_en_tail_gen
      if(I == 0)
        assign freq_mask_en[I] = {WIDTH{1'b1}};
      else
        assign freq_mask_en[I] = ~mask_int[I-1];
    end
  endgenerate

  /* frequencies per tail bit */
  generate
    for(I = 0; I < TAIL_WIDTH; I = I + 1) begin: freq_tail_gen
      for(J = 0; J < WIDTH; J = J + 1) begin: freq_bit_gen
        assign freq_sel[I][(J*SEL_WIDTH)+:SEL_WIDTH] = mask_int[I][J] & freq_mask_en[I][J] ? FREQ_STEPS[SEL_WIDTH-1:0] - I[SEL_WIDTH-1:0] : {SEL_WIDTH{1'b0}};
      end
    end
  endgenerate

  /* sweep control - mask */
  generate
    for(I = 0; I < TAIL_WIDTH; I = I + 1) begin: fsm_gen
      always @ (posedge clk_i, negedge arstn_i) begin
        if(~arstn_i) begin
          mask_int[I]    <= {WIDTH{1'b0}};
          mask_trans[I]  <= 1'b0;
          set_int[I]     <= 1'b0;
          sweep_state[I] <= StateRst;
        end
        else begin
          if(~en_i) begin
            mask_int[I]    <= {WIDTH{1'b0}};
            mask_trans[I]  <= 1'b0;
            set_int[I]     <= 1'b0;
            sweep_state[I] <= StateRst;
          end
          else begin
            case(sweep_state[I])
              StateRst: begin
                mask_int[I]    <= CORNER_SEL ? {1'b1,{(WIDTH-1){1'b0}}} >> START_BIT : {{(WIDTH-1){1'b0}},1'b1} << START_BIT;
                mask_trans[I]  <= CORNER_SEL ? 1'b1 : 1'b0;
                set_int[I]     <= 1'b0;
                sweep_state[I] <= StateRun;
              end
              StateRun: begin
                if(tick_i) begin
                  if(mask_limit[I]) begin
                    sweep_state[I] <= StateWait;
                  end
                  else if(~mask_first_prev[I]) begin
                    sweep_state[I] <= StateCont;
                  end
                end
                set_int[I]  <= 1'b0;
              end
              StateCont: begin
                if(~tick_i) begin
                  mask_int[I]    <= mask_nxt[I];
                  set_int[I]     <= 1'b1;
                  sweep_state[I] <= StateRun;
                end
              end
              StateWait: begin
                if(tick_i) begin
                  if(continue_int)
                    sweep_state[I] <= StateTrans;
                end
              end
              StateTrans: begin
                if(tick_i) begin
                  mask_trans[I]  <= ~mask_trans[I];
                  sweep_state[I] <= StateRun;
                end
              end
              default: begin
                mask_int[I]    <= {WIDTH{1'b0}};
                mask_trans[I]  <= 1'b0;
                set_int[I]     <= 1'b0;
                sweep_state[I] <= StateRst;
              end
            endcase
          end
        end
      end
    end
  endgenerate

  /* output assignment */
  generate
    //..mask
    for(I = 0; I < TAIL_WIDTH; I = I + 1) begin: mask_transpose_tail_gen
      for(J = 0; J < WIDTH; J = J + 1) begin: mask_transpose_bit_gen
        assign mask_int_t[J][I] = mask_int[I][J];
      end
    end
    for(I = 0; I < WIDTH; I = I + 1) begin: mask_output_gen
      assign mask_o[I] = |mask_int_t[I];
    end
    //..frequency selection
    for(I = 0; I < TAIL_WIDTH; I = I + 1) begin: freq_sel_transpose_bit_gen
      for(J = 0; J < FREQ_SEL_PACKED; J = J + 1) begin: freq_sel_transpose_tail_gen
        assign freq_sel_t[J][I] = freq_sel[I][J];
      end
    end
    for(I = 0; I < FREQ_SEL_PACKED; I = I + 1) begin: freq_select_output_gen
      assign select_o[I] = |freq_sel_t[I];
    end
    assign set_o = |set_int;
  endgenerate

endmodule // sweep_transition
