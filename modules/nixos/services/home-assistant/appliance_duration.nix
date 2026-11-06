# Ask for the cycle length when an appliance starts.
#
# The plug cannot tell the programmes apart at the start (see
# appliance_programs.nix), so dafphone gets a question at each start: reply
# with the length (free text, quick buttons for the two most used programmes).
# The answer goes into input_number.<id>_declared_duration, which
# Household · Appliance Programmes uses as the expected length of the running
# cycle (Live Update, rings, Divoom). It is reset when the cycle ends.
#
# Its tag is its own (appliance_duration_<id>): Household · Appliances owns
# appliance_<key>. Unanswered after 30 min, the question disappears.
{ lib }:

let
  appliances = [
    {
      id = "laundry_washing_machine";
      name = "Lave-linge";
      icon = "mdi:washing-machine";
    }
    {
      id = "laundry_dryer";
      name = "Sèche-linge";
      icon = "mdi:tumble-dryer";
    }
    {
      id = "kitchen_dishwasher";
      name = "Lave-vaisselle";
      icon = "mdi:dishwasher";
    }
  ];

  active = a: "binary_sensor.${a.id}_active";
  declared = a: "input_number.${a.id}_declared_duration";
  expected = a: "input_number.${a.id}_expected_duration";
  programs = a: "input_text.${a.id}_programs";
  tag = a: "appliance_duration_${a.id}";
  prefix = a: "DURATION_${a.id}_";

  timeout = 1800;

  # Jinja: the two most used programmes as [minutes, cycles]
  topPrograms = a: ''
    {% set raw = states('${programs a}') %}
    {% set progs = raw | from_json if raw.startswith('[') else [] %}
    {% set top = (progs | sort(attribute='1', reverse=true))[:2] | sort(attribute='0') %}
  '';

  # Jinja: minutes from free text ("90", "1h30", "1 h", "1.5h", "2h 05"), 0 when
  # not understood
  parse = ''
    {% set t = (text | default("")) | lower | replace(',', '.') | trim %}
    {% set hm = t | regex_findall_index('^(\\d+)\\s*h\\s*(\\d+)?\\s*(?:min|m)?$', 0) if t | regex_match('^\\d+\\s*h\\s*(\\d+)?\\s*(?:min|m)?$') else none %}
    {% if hm %}
      {% set minutes = hm[0] | int * 60 + (hm[1] | int(0)) %}
    {% elif t | regex_match('^\\d+\\.\\d+\\s*h$') %}
      {% set minutes = ((t | regex_replace('\\s*h$', "") | float) * 60) | round(0) | int %}
    {% elif t | regex_match('^\\d+\\s*(?:min|m)?$') %}
      {% set minutes = t | regex_replace('\\D', "") | int %}
    {% else %}
      {% set minutes = 0 %}
    {% endif %}
  '';

  ask =
    a: lead:
    {
      action = "notify.mobile_app_dafphone";
      data = {
        title = "${a.name} : quelle durée ?";
        message = "${lead}Durée du cycle en minutes (90, 1h30…). Sans réponse, cette question disparaît dans 30 min.";
        data = {
          tag = tag a;
          group = "Tâches";
          notification_icon = a.icon;
          inherit timeout;
          actions = [
            {
              action = "${prefix a}REPLY";
              title = "Durée…";
              behavior = "textInput";
              textInputButtonTitle = "Valider";
              textInputPlaceholder = "90 ou 1h30";
            }
          ];
        };
      };
    };

  # The same question with the quick buttons added; templated, so the buttons
  # follow the learned programmes.
  askWithButtons =
    a: lead:
    let
      base = ask a lead;
    in
    base
    // {
      data = base.data // {
        data = base.data.data // {
          actions = ''
            ${topPrograms a}
            {% set ns = namespace(out=[{'action': '${prefix a}REPLY', 'title': 'Durée…', 'behavior': 'textInput', 'textInputButtonTitle': 'Valider', 'textInputPlaceholder': '90 ou 1h30'}]) %}
            {% for p in top %}
              {% set ns.out = ns.out + [{'action': '${prefix a}' ~ p[0], 'title': (p[0] // 60 ~ ' h ' ~ '%02d' % (p[0] % 60)) if p[0] >= 60 else (p[0] ~ ' min')}] %}
            {% endfor %}
            {{ ns.out | to_json }}
          '';
        };
      };
    };

  clear = a: {
    action = "notify.mobile_app_dafphone";
    data = {
      message = "clear_notification";
      data.tag = tag a;
    };
  };
in
{
  input_number = lib.listToAttrs (
    map (a: {
      name = "${a.id}_declared_duration";
      value = {
        name = "${a.name} · Durée annoncée";
        icon = a.icon;
        min = 0;
        max = 480;
        step = 1;
        mode = "box";
        unit_of_measurement = "min";
        # 0 = no answer for the running cycle; no `initial`, restarts keep it.
      };
    }) appliances
  );

  automations = [
    {
      id = "dafos_household_appliance_duration";
      alias = "Household · Appliance Duration";
      description = "Au démarrage d'un cycle (lave-linge, sèche-linge, lave-vaisselle), demande sur dafphone la durée du cycle. La réponse (texte libre ou bouton) devient la durée attendue du cycle ; sans réponse en 30 min, la question disparaît. Géré dans Nix (modules/nixos/services/home-assistant/appliance_duration.nix).";
      mode = "queued";
      triggers =
        (map (a: {
          trigger = "state";
          entity_id = active a;
          from = "off";
          to = "on";
          id = "start-${a.id}";
        }) appliances)
        ++ (map (a: {
          trigger = "state";
          entity_id = active a;
          from = "on";
          to = "off";
          id = "end-${a.id}";
        }) appliances)
        ++ [
          {
            trigger = "event";
            event_type = "mobile_app_notification_action";
            id = "answer";
          }
        ];
      actions = [
        {
          choose =
            (map (a: {
              alias = "${a.name} : cycle démarré, poser la question";
              conditions = [
                {
                  condition = "trigger";
                  id = "start-${a.id}";
                }
              ];
              sequence = [
                {
                  alias = "Oublier la durée annoncée du cycle précédent";
                  action = "input_number.set_value";
                  target.entity_id = declared a;
                  data.value = 0;
                }
                (askWithButtons a "")
              ];
            }) appliances)
            ++ (map (a: {
              alias = "${a.name} : cycle terminé, effacer la question et la durée annoncée";
              conditions = [
                {
                  condition = "trigger";
                  id = "end-${a.id}";
                }
              ];
              sequence = [
                (clear a)
                {
                  action = "input_number.set_value";
                  target.entity_id = declared a;
                  data.value = 0;
                }
              ];
            }) appliances)
            ++ (map (a: {
              alias = "${a.name} : réponse reçue";
              conditions = [
                {
                  condition = "template";
                  value_template = "{{ (trigger.event.data.action | string).startswith('${prefix a}') }}";
                }
                {
                  alias = "Le cycle tourne encore";
                  condition = "state";
                  entity_id = active a;
                  state = "on";
                }
              ];
              sequence = [
                {
                  variables.text = ''
                    {% set act = trigger.event.data.action | string %}
                    {{ trigger.event.data.reply_text | default("") if act.endswith('_REPLY') else act.split('_')[-1] }}
                  '';
                }
                {
                  variables.minutes = "${parse}{{ minutes }}";
                }
                {
                  "if" = [
                    {
                      condition = "template";
                      value_template = "{{ 10 <= minutes | int(0) <= 480 }}";
                    }
                  ];
                  "then" = [
                    {
                      action = "input_number.set_value";
                      target.entity_id = [
                        (declared a)
                        (expected a)
                      ];
                      data.value = "{{ minutes | int }}";
                    }
                    (clear a)
                  ];
                  "else" = [
                    (askWithButtons a "« {{ text | trim }} » n'est pas une durée valide. ")
                  ];
                }
              ];
            }) appliances);
        }
      ];
    }
  ];
}
