; i18next translation function calls
; Matches: t('key'), i18n.t('key'), i18next.t('key')

; Standard t() function call
(call_expression
  function: (identifier) @_function (#eq? @_function "t")
  arguments: (arguments
    (string
      (string_fragment) @i18n.key)))

; i18n.t() method call
(call_expression
  function: (member_expression
    object: (identifier) @_object (#eq? @_object "i18n")
    property: (property_identifier) @_method (#eq? @_method "t"))
  arguments: (arguments
    (string
      (string_fragment) @i18n.key)))

; i18next.t() method call
(call_expression
  function: (member_expression
    object: (identifier) @_object (#eq? @_object "i18next")
    property: (property_identifier) @_method (#eq? @_method "t"))
  arguments: (arguments
    (string
      (string_fragment) @i18n.key)))

; Instance.t() for any variable name
(call_expression
  function: (member_expression
    property: (property_identifier) @_method (#eq? @_method "t"))
  arguments: (arguments
    (string
      (string_fragment) @i18n.key)))

; Template literal support
; Matches: t(`key`)
(call_expression
  function: (identifier) @_function (#eq? @_function "t")
  arguments: (arguments
    (template_string
      (string_fragment) @i18n.key)))

; Object-style translation with key property
; Matches: t({ key: 'translation.key' })
(call_expression
  function: (identifier) @_function (#eq? @_function "t")
  arguments: (arguments
    (object
      (pair
        key: (property_identifier) @_prop_name (#eq? @_prop_name "key")
        value: (string
          (string_fragment) @i18n.key)))))
