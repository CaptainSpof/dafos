# Expected cycle length in minutes, the 100% mark of the live-update progress
# bar and of the Maison dashboard's rings. Household · Appliance Programmes
# (../appliance_programs.nix) sets it from the programme lengths it learns:
# the shortest one the running cycle has not yet outlasted.
#
# No `initial`: it would reset the value on every restart.
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
