
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
  wire  [LED_WIDTH-1:0] mask_int;
  wire                  tick;

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


  /* tick generation */
  freq_gen
    # (
        .CLK_FREQ   (CLK_FREQ),
        .FREQ_STEPS (TICK_FREQ_STEPS),
        .MAX_FREQ   (TICK_MAX_FREQ),
        .MIN_FREQ   (TICK_MIN_FREQ),
        .SCALE_DIV  (TICK_SCALE_DIV),
        .INIT_STEP  (TICK_INIT_STEP)
      )
    tick_ctrl (
      /* clock and reset - port*/
      .clk_i      (clk_i),
      .arstn_i    (arstn_i),

      /* operation control - port */
      .en_i       (en_i),
      .pause_i    (pause_i),
      .mask_i     (1'b1),

      /* freq setup control - port */
      .set_i      (1'b0),
      .select_i   (0),

      /* freq step control - port */
      .freq_up_i  (freq_up),
      .freq_dwn_i (freq_dwn),

      /* oscillator output */
      .freq_o     (tick)
    );

  /* sweep transition effect */
  sweep_transition
    # (
        .WIDTH      (LED_WIDTH)
        //.FREQ_STEPS (LED_FREQ_STEPS)
      )
    sweep_inst (
      /* clock and reset - port */
      .clk_i    (clk_i),
      .arstn_i  (arstn_i),

      /* operation control - port */
      .en_i     (en_i),
      .tick_i   (tick),

      /* mask bits and freq selection - port */
      .mask_o   (mask_int)
      //.select_o (freq_select_packed)
    );

  /* unpack frequency selector by bit position */
  /*generate
    for(I = 0; I < LED_WIDTH; I = I + 1) begin: unpack_freq_select_gen
      assign freq_select[I] = freq_select_packed[(I*LED_WIDTH)+:LED_WIDTH];
    end
  endgenerate*/

  /* blink led inst */
  generate
    for(I = 0; I < LED_WIDTH; I = I + 1) begin: blink_led_gen
      freq_gen
        # (
            .CLK_FREQ   (CLK_FREQ),
            .FREQ_STEPS (LED_FREQ_STEPS),
            .MAX_FREQ   (LED_MAX_FREQ),
            .MIN_FREQ   (LED_MIN_FREQ),
            .SCALE_DIV  (LED_SCALE_DIV),
            .INIT_STEP  (LED_INIT_STEP)
          )
        blink_led_inst (
          /* clock and reset - port*/
          .clk_i      (clk_i),
          .arstn_i    (arstn_i),

          /* operation control - port */
          .en_i       (en_i),
          .pause_i    (pause_i),
          .mask_i     (mask_int[I]),

          /* freq setup control - port */
          .set_i      (/*freq_set*/0),
          .select_i   (/*freq_select[I]*/0),

          /* freq step control - port */
          .freq_up_i  (1'b0),
          .freq_dwn_i (1'b0),

          /* oscillator output */
          .freq_o     (led_int[I])
        );
    end
  endgenerate

  /* output assignment */
  assign led_o = led_int;

endmodule // fpga_top

`default_nettype wire
