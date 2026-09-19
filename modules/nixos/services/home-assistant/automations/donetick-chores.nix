# Actionable phone notification for every Donetick chore when it falls due.
#
# One automation handles both ends so the notification and its buttons can't
# drift apart:
#   - the donetick calendar fires a `start` event per chore occurrence; the
#     event uid is `donetick_<task_id>` (or `donetick_<task_id>_<suffix>` for
#     projected recurrences), which is the only place the id survives;
#   - the companion app sends `mobile_app_notification_action` back with
#     `DONETICK_<DONE|SKIP|SNOOZE>_<task_id>`.
#
# Snooze stays inside HA (a delay, then re-send) on purpose: donetick's
# `update_task` hits PUT /eapi/v1/chore/{id}, which requires the name and
# writes NULL to the description when it isn't passed. A pending snooze does
# not survive an HA restart.
{
  id = "donetick_chore_due_notification";
  alias = "Donetick: notify due chores";
  mode = "parallel";
  max = 25;

  triggers = [
    {
      trigger = "calendar";
      id = "due";
      event = "start";
      entity_id = "calendar.donetick_chores_chores";
    }
    # Chores without a due time become all-day events starting at midnight;
    # notify those in the morning instead.
    {
      trigger = "calendar";
      id = "due_all_day";
      event = "start";
      offset = "09:00:00";
      entity_id = "calendar.donetick_chores_chores";
    }
    {
      trigger = "event";
      id = "action";
      event_type = "mobile_app_notification_action";
    }
  ];

  conditions = [
    {
      condition = "template";
      value_template = ''
        {% if trigger.id == 'action' %}
          {{ trigger.event.data.action is string and trigger.event.data.action.startswith('DONETICK_') }}
        {% else %}
          {{ trigger.calendar_event.uid is string
             and trigger.calendar_event.uid.startswith('donetick_')
             and trigger.calendar_event.all_day == (trigger.id == 'due_all_day') }}
        {% endif %}
      '';
    }
  ];

  variables = {
    # Donetick username -> companion app notify service; unknown assignees
    # fall back to the first entry's phone.
    notify_targets = {
      daf = "mobile_app_dafphone";
    };
    kind = ''
      {{ trigger.event.data.action.split('_')[1] | lower if trigger.id == 'action' else 'due' }}
    '';
    task_id = ''
      {% if trigger.id == 'action' %}
        {{ trigger.event.data.action.split('_')[2] | int }}
      {% else %}
        {{ trigger.calendar_event.uid | regex_findall_index('^donetick_(\d+)') | int }}
      {% endif %}
    '';
  };

  actions = [
    {
      choose = [
        {
          conditions = "{{ kind == 'done' }}";
          sequence = [
            {
              action = "donetick.complete_task";
              data.task_id = "{{ task_id }}";
            }
            { stop = "Chore completed from the notification"; }
          ];
        }
        {
          conditions = "{{ kind == 'skip' }}";
          sequence = [
            {
              action = "donetick.skip_task";
              data.task_id = "{{ task_id }}";
            }
            { stop = "Chore skipped from the notification"; }
          ];
        }
        {
          conditions = "{{ kind == 'snooze' }}";
          sequence = [ { delay = "01:00:00"; } ];
        }
      ];
    }
    {
      variables = {
        chore = ''
          {{ integration_entities('donetick')
             | select('match', 'sensor\.')
             | select('is_state_attr', 'task_id', task_id)
             | first | default("") }}
        '';
      };
    }
    # Drop it if the chore was deleted, or completed/rescheduled elsewhere
    # (matters after a snooze).
    {
      condition = "template";
      value_template = ''
        {% set due = state_attr(chore, 'next_due_date') if chore else none %}
        {{ due is not none and as_datetime(due) <= now() + timedelta(minutes=5) }}
      '';
    }
    {
      action = "notify.{{ notify_targets.get(state_attr(chore, 'assigned_to'), notify_targets.values() | first) }}";
      data = {
        title = "Tâche à faire";
        message = "{{ states(chore) }}";
        data = {
          # Same tag per chore: a snoozed re-send replaces the old one.
          tag = "donetick_{{ task_id }}";
          group = "donetick";
          channel = "Donetick";
          clickAction = "https://donetick.daftdaf.dev/chores/{{ task_id }}";
          actions = [
            {
              action = "DONETICK_DONE_{{ task_id }}";
              title = "Fait";
            }
            {
              action = "DONETICK_SKIP_{{ task_id }}";
              title = "Passer";
            }
            {
              action = "DONETICK_SNOOZE_{{ task_id }}";
              title = "Dans 1 h";
            }
          ];
        };
      };
    }
  ];
}
