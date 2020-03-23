
`default_nettype none

module fpga_top (/*AUTOARG*/
   // Outputs
   led_o,
   // Inputs
   clk_i, arstn_i, freq_up_i, freq_dwn_i
   );

  /* includes */
  `include "fpga_top.vh"

  /* local parameters */
  localparam DBNC_WDTH  = $clog2(DEBOUNCE + 1);

  /* clock and reset - port*/
  input   wire  clk_i;
  input   wire  arstn_i;

  /* freq step control - port */
  input   wire  freq_up_i;
  input   wire  freq_dwn_i;

  /* led output */
  output  wire  led_o;

  /* regs n wires */
  reg [NUM_SYNC-1:0]  freq_up_sync;
  reg [NUM_SYNC-1:0]  freq_dwn_sync;
  reg [DBNC_WDTH-1:0] debounce_counter;
  wire                freq_up_active;
  wire                freq_dwn_active;
  wire                button_pushed;
  wire                button_released;
  reg                 freq_up;
  reg                 freq_dwn;

  /* integers and genvars */
  integer i;

  /* button state declaration */
  reg button_state;
  localparam IDLE   = 1'b0;
  localparam ACTION = 1'b1;

  /* active state buttons */
  generate
    if(BTN_ACTIVE) begin  //..buttons are active-high
      assign freq_up_active   = freq_up_i;
      assign freq_dwn_active  = freq_dwn_i;
    end
    else begin  //..buttons are active-low
      assign freq_up_active   = ~freq_up_i;
      assign freq_dwn_active  = ~freq_dwn_i;
    end
  endgenerate

  /* synchronizers */
  always @ (posedge clk_i, negedge arstn_i) begin
    if(~arstn_i) begin
      for(i=0; i<NUM_SYNC; i=i+1) begin
        freq_up_sync[i]   <= 1'b0;
        freq_dwn_sync[i]  <= 1'b0;
      end
    end
    else begin
      for(i=0; i<NUM_SYNC; i=i+1) begin
        if(i==0) begin
          freq_up_sync[i]   <= freq_up_active;
          freq_dwn_sync[i]  <= freq_dwn_active;
        end
        else begin
          freq_up_sync[i]   <= freq_up_sync[i-1];
          freq_dwn_sync[i]  <= freq_dwn_sync[i-1];
        end
      end
    end
  end

  /* button change */
  assign button_pushed    = freq_up_sync[NUM_SYNC-1] | freq_dwn_sync[NUM_SYNC-1];
  assign button_released  = ~button_pushed;

  /* button state control */
  always @ (posedge clk_i, negedge arstn_i) begin
    if(~arstn_i) begin
      freq_up           <= 1'b0;
      freq_dwn          <= 1'b0;
      debounce_counter  <= {DBNC_WDTH{1'b0}};
      button_state      <= IDLE;
    end
    else begin
      case(button_state)
        IDLE: begin
          if(button_pushed) begin //..a button has been pushed
            if(debounce_counter == DEBOUNCE) begin
              freq_up           <= freq_up_sync[NUM_SYNC-1];
              freq_dwn          <= freq_dwn_sync[NUM_SYNC-1];
              debounce_counter  <= {DBNC_WDTH{1'b0}};
              button_state      <= ACTION;
            end
            else
              debounce_counter  <= debounce_counter + {{(DBNC_WDTH-1){1'b0}},1'b1};
          end
          else
            debounce_counter  <= {DBNC_WDTH{1'b0}};
        end
        ACTION: begin
          freq_up   <= 1'b0;
          freq_dwn  <= 1'b0;
          if(button_released) begin //..the buttons are released
            if(debounce_counter == DEBOUNCE) begin
              debounce_counter  <= {DBNC_WDTH{1'b0}};
              button_state      <= IDLE;
            end
            else
              debounce_counter  <= debounce_counter + {{(DBNC_WDTH-1){1'b0}},1'b1};
          end
          else
            debounce_counter  <= {DBNC_WDTH{1'b0}};
        end
      endcase
    end
  end

  /* blink led module */
  defparam blink_led_inst.CLK_FREQ   = CLK_FREQ;
  defparam blink_led_inst.FREQ_STEPS = FREQ_STEPS;
  defparam blink_led_inst.MAX_FREQ   = MAX_FREQ;
  defparam blink_led_inst.MIN_FREQ   = MIN_FREQ;
  defparam blink_led_inst.SCALE_DIV  = SCALE_DIV;
  blink_led
    blink_led_inst (
      /* clock and reset - port*/
      .clk_i      (clk_i),
      .arstn_i    (arstn_i),

      /* freq step control - port */
      .freq_up_i  (freq_up),
      .freq_dwn_i (freq_dwn),

      /* led output */
      .led_o      (led_o)
    );

endmodule // fpga_top

`default_nettype wire
