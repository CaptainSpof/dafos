# Start time of the running appliance cycle, written by the
# "Household · Appliances" automation. Restored across restarts, unlike
# last_changed, so progress keeps counting after a deploy mid-cycle.
{
  laundry_washing_machine_started_at = {
    name = "Buanderie · Lave-linge démarré à";
    icon = "mdi:washing-machine";
    has_date = true;
    has_time = true;
  };
  laundry_dryer_started_at = {
    name = "Buanderie · Sèche-linge démarré à";
    icon = "mdi:tumble-dryer";
    has_date = true;
    has_time = true;
  };
  kitchen_dishwasher_started_at = {
    name = "Cuisine · Lave-vaisselle démarré à";
    icon = "mdi:dishwasher";
    has_date = true;
    has_time = true;
  };
}
