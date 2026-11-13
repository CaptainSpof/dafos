# HelloFresh weekly box, driven from the Stream Deck's HelloFresh menu.
#
# Boxes arrive on Wednesday and each one must be prepared (meals picked) by the
# Friday before, so an order cycle runs Saturday 00:00 → Friday 23:59.
# input_select.hellofresh_status holds the state of the current cycle and goes
# back to "À préparer" every Saturday; the Deck's keys set the other states.
# "À préparer" is the alert state: the Deck's notification key shows it.
_:

let
  status = "input_select.hellofresh_status";
in
{
  input_select.hellofresh_status = {
    name = "HelloFresh · Statut";
    icon = "mdi:food";
    options = [
      "À préparer"
      "Préparée"
      "En pause"
    ];
    # No `initial`: HA restores the last state across restarts.
  };

  automations = [
    {
      id = "dafos_hellofresh_new_cycle";
      alias = "HelloFresh · New Cycle";
      description = "Chaque samedi, la box de la semaine suivante est à préparer (avant vendredi). Géré dans Nix (modules/nixos/services/home-assistant/hellofresh.nix).";
      mode = "single";
      triggers = [
        {
          trigger = "time";
          at = "00:00:00";
          weekday = [ "sat" ];
        }
      ];
      actions = [
        {
          alias = "Nouvelle box à préparer";
          action = "input_select.select_option";
          target.entity_id = status;
          data.option = "À préparer";
        }
      ];
    }
  ];
}
