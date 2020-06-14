
`default_nettype none

module fpga_top (/*AUTOARG*/
   // Outputs
   led_o,
   // Inputs
   clk_i, arstn_i, en_i, pause_i, freq_up_i, freq_dwn_i
   );

  /* includes */
  `include "fpga_top.vh"

  /* local parameters */
  localparam DBNC_WDTH  = $clog2(DEBOUNCE + 1);
  localparam INIT_STEP  = 3;
  localparam START_BIT  = 0;
  localparam LED_PTR    = $clog2(LED_WIDTH);

  /* clock and reset - port*/
  input   wire  clk_i;
  input   wire  arstn_i;

  /* enable and pause control - port */
  input   wire  en_i;
  input   wire  pause_i;

  /* freq step control - port */
  input   wire  freq_up_i;
  input   wire  freq_dwn_i;

  /* led output */
  output  wire  [LED_WIDTH-1:0] led_o;

  /* regs n wires */
  reg   [NUM_SYNC-1:0]  freq_up_sync;
  reg   [NUM_SYNC-1:0]  freq_dwn_sync;
  reg   [DBNC_WDTH-1:0] debounce_counter;
  wire                  freq_up_active;
  wire                  freq_dwn_active;
  wire                  button_pushed;
  wire                  button_released;
  reg                   freq_up;
  reg                   freq_dwn;
  wire  [LED_WIDTH-1:0] led_int;
  reg   [LED_WIDTH-1:0] mask_int;
  wire  [LED_WIDTH-1:0] mask_nxt;
  reg   [LED_PTR-1:0]   mask_ptr;
  reg                   mask_trans;
  wire                  mask_limit;
  wire  [LED_PTR-1:0]   mask_ptr_prev [LED_WIDTH-1:0];
  wire  [LED_PTR-1:0]   mask_ptr_nxt  [LED_WIDTH-1:0];
  wire  [LED_PTR-1:0]   mask_ptr_new  [LED_WIDTH-1:0];

  /* fsm declaration */
  reg   [2:0] sweep_state;
  localparam StateRst  = 3'b000;
  localparam StateRun  = 3'b011;
  localparam StateCont = 3'b101;

  /* integers and genvars */
  integer i;
  genvar I;

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

  /* sweep pointer assignments - mask */
  /*
   * transition-a: [000 --> 001] [001 --> 010] [010 --> 011] [011 --> 100] [100 --> 101] [101 --> 110] [110 --> 111]
   * transition-b: [111 --> 110] [110 --> 101] [101 --> 100] [100 --> 011] [011 --> 010] [010 --> 001] [001 --> 000]
   */
  generate
    for(I = 0; I < LED_WIDTH; I = I + 1) begin: mask_transitions_gen
      assign mask_ptr_nxt[I]  = (I+1)%LED_WIDTH;
      assign mask_ptr_prev[I] = (I+LED_WIDTH-1);
      assign mask_nxt[I]      = mask_trans ? mask_int[mask_ptr_nxt[I]] : mask_int[mask_ptr_prev[I]];
      assign mask_ptr_new[I]  = mask_trans ? mask_ptr_prev[I] : mask_ptr_nxt[I];
    end
    assign mask_limit = mask_trans ? mask_int[0] : mask_int[LED_WIDTH-1];
  endgenerate

  /* sweep control - mask */
  always @ (posedge clk_i, negedge arstn_i) begin
    if(~arstn_i) begin
      mask_int    <= {LED_WIDTH{1'b0}};
      mask_ptr    <= START_BIT[LED_PTR-1:0];
      mask_trans  <= 1'b0;
      sweep_state <= StateRst;
    end
    else begin
      if(~en_i) begin
        mask_int    <= {LED_WIDTH{1'b0}};
        mask_ptr    <= START_BIT[LED_PTR-1:0];
        mask_trans  <= 1'b0;
        sweep_state <= StateRst;
      end
      else begin
        case(sweep_state)
          StateRst: begin
            mask_int    <= {{(LED_WIDTH-1){1'b0}},1'b1};
            mask_ptr    <= START_BIT[LED_PTR-1:0];
            mask_trans  <= 1'b0;
            sweep_state <= StateRun;
          end
          StateRun: begin
            if(led_int[mask_ptr]) begin
              mask_trans  <= mask_limit ? ~mask_trans : mask_trans;
              sweep_state <= StateCont;
            end
          end
          StateCont: begin
            if(~led_int[mask_ptr]) begin
              mask_int    <= mask_nxt;
              mask_ptr    <= mask_ptr_new[mask_ptr];
              sweep_state <= StateRun;
            end
          end
          default: begin
            mask_int    <= {LED_WIDTH{1'b0}};
            mask_ptr    <= START_BIT[LED_PTR-1:0];
            mask_trans  <= 1'b0;
            sweep_state <= StateRst;
          end
        endcase
      end
    end
  end

  /* blink led inst */
  generate
    for(I = 0; I < LED_WIDTH; I = I + 1) begin: blink_led_sweep_gen
      blink_led
        # (
            .CLK_FREQ   (CLK_FREQ),
            .FREQ_STEPS (FREQ_STEPS),
            .MAX_FREQ   (MAX_FREQ),
            .MIN_FREQ   (MIN_FREQ),
            .SCALE_DIV  (SCALE_DIV),
            .INIT_STEP  (INIT_STEP)
          )
        blink_led_inst (
          /* clock and reset - port*/
          .clk_i      (clk_i),
          .arstn_i    (arstn_i),

          /* operation control - port */
          .en_i       (en_i),
          .pause_i    (pause_i),
          .mask_i     (mask_int[I]),

          /* freq step control - port */
          .freq_up_i  (freq_up),
          .freq_dwn_i (freq_dwn),

          /* led output */
          .led_o      (led_int[I])
      );
    end
  endgenerate

  /* output assignment */
  assign led_o = led_int;

endmodule // fpga_top

`default_nettype wire
