# NOTE: includes workaround for upstream bug
#       <https://www.nushell.sh/cookbook/external_completers.html#err-unknown-shorthand-flag-using-carapace>
let carapace_completer = {|spans: list<string>|
    carapace $spans.0 nushell $spans
    | from json
    | if ($in | default [] | where value =~ '^-.*ERR$' | is-empty) { $in } else { null }
}

# https://www.nushell.sh/cookbook/external_completers.html#fish-completer
let fish_completer = {|spans|
    fish --command $'complete "--do-complete=($spans | str join " ")"'
    | $"value(char tab)description(char newline)" + $in
    | from tsv --flexible --no-infer
}

# Default to carapace, with optional command-specific overrides to fish completions.
# via <https://www.nushell.sh/cookbook/external_completers.html#putting-it-all-together>
# let external_completers = {|spans|

#     # Workaround for lack of alias completion (via manual: <https://www.nushell.sh/cookbook/external_completers.html#alias-completions>)
#     # TODO(<https://github.com/nushell/nushell/issues/8483>): remove
#     let expanded_alias = (scope aliases | where name == $spans.0 | get -i 0 | get -i expansion)
#     let spans = (if $expanded_alias != null  {
#         $spans | skip 1 | prepend ($expanded_alias | split words)
#     } else { $spans })

#     {
#         # carapace completions are incorrect for nu
#         nu: $fish_completer
#         # fish completes commits and branch names in a nicer way
#         git: $fish_completer
#     } | get -i $spans.0 | default $carapace_completer | do $in $spans

# }

# def "history fzf" [] {
#   commandline (
#     history
#       | each { |it| $it.command }
#       | uniq
#       | reverse
#       | str join (char -i 0)
#       | fzf --read0 --layout=reverse --height=40% -q (commandline)
#       | decode utf-8
#       | str trim
#   )
# }

let dark_theme = {
  separator: "#a89984"
  leading_trailing_space_bg: { attr: "n" }
  header: { fg: "#98971a" attr: "b" }
  empty: "#458588"
  bool: {|| if $in { "#8ec07c" } else { "light_gray" } }
  int: "#a89984"
  filesize: {|e|
      if $e == 0b {
          "#a89984"
      } else if $e < 1mb {
          "#689d6a"
      } else {{ fg: "#458588" }}
  }
  duration: "#a89984"
  date: {|| (date now) - $in |
      if $in < 1hr {
          { fg: "#cc241d" attr: "b" }
      } else if $in < 6hr {
          "#cc241d"
      } else if $in < 1day {
          "#d79921"
      } else if $in < 3day {
          "#98971a"
      } else if $in < 1wk {
          { fg: "#98971a" attr: "b" }
      } else if $in < 6wk {
          "#689d6a"
      } else if $in < 52wk {
          "#458588"
      } else { "dark_gray" }
  }
  range: "#a89984"
  float: "#a89984"
  string: "#a89984"
  nothing: "#a89984"
  binary: "#a89984"
  cellpath: "#a89984"
  row_index: { fg: "#98971a" attr: "b" }
  record: "#a89984"
  list: "#a89984"
  block: "#a89984"
  hints: "dark_gray"
  search_result: { fg: "#cc241d" bg: "#a89984" }

  shape_and: { fg: "#b16286" attr: "b" }
  shape_binary: { fg: "#b16286" attr: "b" }
  shape_block: { fg: "#458588" attr: "b" }
  shape_bool: "#8ec07c"
  shape_custom: "#98971a"
  shape_datetime: { fg: "#689d6a" attr: "b" }
  shape_directory: "#689d6a"
  shape_external: "#689d6a"
  shape_externalarg: { fg: "#98971a" attr: "b" }
  shape_filepath: "#689d6a"
  shape_flag: { fg: "#458588" attr: "b" }
  shape_float: { fg: "#b16286" attr: "b" }
  shape_garbage: { fg: "#FFFFFF" bg: "#FF0000" attr: "b" }
  shape_globpattern: { fg: "#689d6a" attr: "b" }
  shape_int: { fg: "#b16286" attr: "b" }
  shape_internalcall: { fg: "#689d6a" attr: "b" }
  shape_list: { fg: "#689d6a" attr: "b" }
  shape_literal: "#458588"
  shape_match_pattern: "#98971a"
  shape_matching_brackets: { attr: "u" }
  shape_nothing: "#8ec07c"
  shape_operator: "#d79921"
  shape_or: { fg: "#b16286" attr: "b" }
  shape_pipe: { fg: "#b16286" attr: "b" }
  shape_range: { fg: "#d79921" attr: "b" }
  shape_record: { fg: "#689d6a" attr: "b" }
  shape_redirection: { fg: "#b16286" attr: "b" }
  shape_signature: { fg: "#98971a" attr: "b" }
  shape_string: "#98971a"
  shape_string_interpolation: { fg: "#689d6a" attr: "b" }
  shape_table: { fg: "#458588" attr: "b" }
  shape_variable: "#b16286"

  background: "#282828"
  foreground: "#ebdbb2"
  cursor: "#ebdbb2"
}

$env.config = {
  completions: {
    case_sensitive: false
    algorithm: "fuzzy"
    # external: {
    #   enable: true,
    #   completer: $external_completers
    # }
  }
  color_config: $dark_theme
}
