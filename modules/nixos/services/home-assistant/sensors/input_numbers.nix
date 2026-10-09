# Expected cycle length in minutes, the 100% mark of the live-update progress
# bar. The "Household · Appliances" automation folds every finished cycle into
# it (moving average), so it tracks the programmes actually used.
#
# No `initial`: it would reset the learned value on every restart. Seed a new
# entry once with input_number.set_value.
let
  duration = name: icon: {
    inherit name icon;
    min = 10;
    max = 480;
    step = 1;
    mode = "box";
    unit_of_measurement = "min";
  };
in
{
  laundry_washing_machine_expected_duration = duration "Laundry · Washing Machine expected duration" "mdi:washing-machine";
  laundry_dryer_expected_duration = duration "Laundry · Dryer expected duration" "mdi:tumble-dryer";
  kitchen_dishwasher_expected_duration = duration "Kitchen · Dishwasher expected duration" "mdi:dishwasher";
}
