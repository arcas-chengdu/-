#-----read in design---------------
#set_opt -top main
read  -sysv traffic.v

#---- define clock and reset-------
def_clk clk
def_rst reset_n -val 0
set_opt -engine cov
#-----constranit-------------------
#add_cons -postreset reset_n -pinval 1
add_cov  main.timer.state
#add_cons -pin car_present -pinvalue 1
show_init main.timer.state
#-----set option-------------------
#add_prop forbid_hwy_light_and_farm_light_green_same_time

#-----process----------------------
#prove forbid_hwy_light_and_farm_light_same_same_time
prove
#-----show results-----------------
#show -property forbid_hwy_light_and_farm_light_green_same_time
#show -property forbid_hwy_light_and_farm_light_same_same_time
#show -property *
show_prop -all
show_cov -coverage
#show_prop * -cover -list
