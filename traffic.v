`define YES 1
`define NO 0
`define START 0
`define SHORT 1
`define LONG 2
`define GREEN 2'd0
`define YELLOW 2'd1
`define RED 2'd2
`define TIMER_WIDTH 5
`define SVA_ON 1
/*****************************************************************************/
module main(clk, reset_n, car_present, long_timer_value,
short_timer_value, farm_light, hwy_light);
input clk, reset_n, car_present;
input [`TIMER_WIDTH-1:0] long_timer_value;
input [`TIMER_WIDTH-1:0] short_timer_value;
output [1:0] farm_light;
output [1:0] hwy_light;
wire start_timer, short_timer, long_timer;
wire enable_farm, farm_start_timer, enable_hwy, hwy_start_timer;
assign start_timer = farm_start_timer || hwy_start_timer;
timer timer(clk, 
            reset_n, 
            start_timer, 
            short_timer,
            long_timer, 
            long_timer_value, 
            short_timer_value);

farm_control farm_control(clk, 
                          reset_n, 
                          car_present,
                          enable_farm, 
                          short_timer, 
                          long_timer, 
                          farm_light,
                          farm_start_timer, 
                          enable_hwy);
hwy_control hwy_control (clk,  
                         reset_n,  
                         car_present,
                         enable_hwy, 
                         short_timer, 
                         long_timer, 
                         hwy_light,
                         hwy_start_timer,
                         enable_farm);


`ifdef SVA_ON
//contraint1:The short timer value should be smaller than the longer timer value
//short_time_lte_long_timer: assume property(short_timer_value  < long_timer_value) ;
short_time_lte_long_timer_assume: assume property((short_timer_value==5'd5)&& (long_timer_value==5'd15)) ;
//subsystem:
//1.PASS:The traffic light on both sides can't be same in any time after reset  
forbid_hwy_light_and_farm_light_same_same_time: assert property(!(hwy_light==farm_light));
//2.PASS:The traffic light can't be yellow and another be green
forbid_yellow_and_green__same_time: assert property(!(((hwy_light ==`YELLOW) && (farm_light == `GREEN)) ||  ((hwy_light == `GREEN) && (farm_light == `YELLOW))) );
//3.test:FAIL:The traffic light on both sides maybe green at the same time
//maybe_hwy_light_and_farm_light_green_same_time: assert property((hwy_light == `GREEN) && (farm_light == `GREEN)) ;

`endif

endmodule

/*****************************************************************************/
/* From the START state, the timer produces the signal
* "short" after a non-deterministic amount of time. The signal
* "short" remains asserted until the timer is reset (via the
* signal "start"). From the SHORT state, the timer produces
* the signal "long" after a non-deterministic amount of time.
* The signal "long" remains asserted until the timer is reset
* (via the signal "start").
*/
module timer(clk, reset_n, start, short, long, long_timer_value,
short_timer_value);
input clk, reset_n, start;
output short, long;
input [`TIMER_WIDTH-1:0] long_timer_value, short_timer_value;
reg [1:0] state;
reg [`TIMER_WIDTH-1:0] timer;
//parameter SHORT = 1;
//parameter LONG  = 2;
assign short = ((state == `SHORT) || (state == `LONG));
assign long = (state == `LONG);  
always @(posedge clk)
begin
  if (start || reset_n == 1'b0) begin
     timer <= 0;
     state <= `START;
  end
  else begin
     case (state)
     `START:
        begin
          timer <= timer + 1;
          if (timer >= short_timer_value) 
             state <= `SHORT;
        end
      `SHORT:
         begin
           timer <= timer + 1;
           if (timer >= long_timer_value) 
              state <= `LONG;
         end
endcase
end
end
//constraint2:
`ifdef SVA_ON
long_not_be_one_in_reset_state_assume:assume property(@(posedge clk) (!reset_n) |-> (!long) );
`endif
endmodule

/****************************************************************************/
/* Farm light stays RED until it is enabled by the highway
* control. At this point, it resets the timer, and moves to
* GREEN. It stays in GREEN until there are no cars, or the
* long timer expires. At this point, it moves to YELLOW and
* resets the timer. It stays in YELLOW until the short
* timer expires. At this point, it moves to RED and enables
* the highway controller.
*/
module farm_control(clk, reset_n, car_present, enable_farm,
short_timer, long_timer, farm_light, farm_start_timer,
enable_hwy);
input clk, reset_n, car_present, enable_farm, short_timer,
long_timer;
output [1:0] farm_light;
output farm_start_timer, enable_hwy;
reg [1:0] farm_light;
assign farm_start_timer = (((farm_light == `GREEN) &&
                          ((car_present == `NO) || long_timer)) ||
                          (farm_light == `RED) && enable_farm);
assign enable_hwy = ((farm_light == `YELLOW) && short_timer);
always @(posedge clk) begin
if (reset_n == 1'b0) begin
farm_light <= `RED;
end
else begin
case (farm_light)
`GREEN:
if ((car_present == `NO) || long_timer)
farm_light <= `YELLOW;
`YELLOW:
if (short_timer) farm_light <= `RED;
`RED:
if (enable_farm) farm_light <= `GREEN;
endcase
end
end
//If there are no more cars on the farm road when the farm light is green, the light should switch to yellow
//This condition asserts that the traffic light controller should always maximize the green time for the
//highway.

`ifdef SVA_ON
//farm control:
//1.PASS:farm light can only be one of GREEN  YELLOW  and RED  
farm_light_only_be_GREEN_or_YELLOW_or_RED: assert property((farm_light==`GREEN) || (farm_light==`YELLOW) || (farm_light==`RED));
//2.PASS:when farm light is in GREEN and car_present desserted,farm light should be YELLOW in next cycle
farm_light_will_be_YELLOW_when_GREEN_and_no_car: assert property( @(posedge clk) ((farm_light==`GREEN) && (car_present==`NO)) |=> (farm_light==`YELLOW));
//3.PASS:when farm light is in GREEN and time limited asserted,farm light should be YELLOW in next cycle
farm_light_will_be_YELLOW_when_GREEN_and_time_limit: assert property( @(posedge clk)  ((farm_light==`GREEN) && long_timer) |=> (farm_light==`YELLOW));                       
//4.PASS:when farm light is in YELLOW and time limited asserted,farm light should be RED in next cycle
farm_light_will_be_RED_when_YELLOW_and_time_limit: assert property( @(posedge clk) ((farm_light==`YELLOW) && short_timer) |=> (farm_light==`RED));                           
//5.PASS:when farm light is in RED ,besides, hwy_light is YELLOW and time limited asserted, farm light should be GREEN in next cycle
farm_light_will_be_GREEN_when_farm_light_is_RED_and_hwy_light_is_YELLOW_and_time_limit: assert property ( @(posedge clk) ((farm_light==`RED)&&enable_farm )  |=> (farm_light==`GREEN) );

`endif
endmodule
/******************************************************************/
/* Highway light stays RED until it is enabled by the farm
* control. At this point, it resets the timer, and moves to
* GREEN. It stays in GREEN until there are cars and the
* long timer expires. At this point, it moves to YELLOW and
* resets the timer. It stays in YELLOW until the short
* timer expires. At this point, it moves to RED and enables
* the farm controller.
*/
module hwy_control(clk, reset_n, car_present, enable_hwy,
short_timer, long_timer, hwy_light, hwy_start_timer,
enable_farm);
input clk, reset_n, car_present, enable_hwy, short_timer,
long_timer;
output [1:0] hwy_light;
output hwy_start_timer, enable_farm;
reg [1:0] hwy_light;
assign hwy_start_timer =
(((hwy_light == `GREEN) && ((car_present == `YES) &&
long_timer)) || (hwy_light == `RED) && enable_hwy);
assign enable_farm = ((hwy_light == `YELLOW) &&
short_timer);
always @(posedge clk) begin
if (reset_n == 1'b0) begin
  hwy_light <= `GREEN;
end
else begin
case (hwy_light)
`GREEN:
if ((car_present ==`YES) && long_timer)
hwy_light <=`YELLOW;
`YELLOW:
if (short_timer) hwy_light <= `RED;
`RED:
  if (enable_hwy) hwy_light <= `GREEN;
endcase
end
end
/******************************************************************/
//It is not possible for a car on the farm road to wait forever
//In this assertion, the internal timer counts up to 32, allowing enough time for cars on the major road to
//pass,
//thus, long_timer is asserted. At this point, the farm road is checked for the presence of a car. The maximum
//length of the farm road.s red light is then 32 cycles.
/******************************************************************/

`ifdef SVA_ON
//hwy control:
//1.PASS:hwy light can only be one of GREEN  YELLOW  and RED 
hwy_light_only_be_GREEN_or_YELLOW_or_RED: assert property((hwy_light==`GREEN) || (hwy_light==`YELLOW) || (hwy_light==`RED));
//2.PASS::when hwy light is in GREEN and time limited asserted,and farm road have car,hwy light should be YELLOW in next cycle
hwy_light_will_be_YELLOW_when_GREEN_and_time_limit_and_farm_road_have_car: assert property(@(posedge clk) disable iff(reset_n==1'b0) ((hwy_light==`GREEN)&&(car_present==`YES)&&long_timer)  |=> (hwy_light==`YELLOW) );
//3.PASS:when hwy light is in YELLOW and time limited asserted,hwy light should be RED in next cycle
hwy_light_will_be_RED_when_YELLOW_and_time_limit:assert property(@(posedge clk) ((hwy_light==`YELLOW)&&short_timer) |=> (hwy_light==`RED));
//4.PASS:when hwy light is in RED ,and farm light is in YELLOW and time limited asserted,hwy light should be GEEN in next cycle
hwy_light_will_be_GREEN_when_RED_and_farm_light_in_YELLOW_and_time_limit: assert property(@(posedge clk) ((hwy_light==`RED)&& enable_hwy) |=> (hwy_light==`GREEN) );
//5.PASS:hwy_light eventually be GREEN,when it is RED
hwy_light_will_eventually_be_GREEN_when_RED:assert property (@(posedge clk) hwy_light==`RED |=> s_eventually (hwy_light==`GREEN ) );
   

`endif

endmodule


