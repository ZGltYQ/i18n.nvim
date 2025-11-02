; i18next translation function calls
; Matches: t('key'), i18n.t('key'), i18next.t('key')

; getFixedT function call
(variable_declarator
  name: (identifier) @i18n.t_func_name
  value: (call_expression
    function: [
      (identifier)
      (member_expression)
    ] @get_fixed_t_func (#match? @get_fixed_t_func "getFixedT$")
    ; 1: lang, 2: ns, 3: keyPrefix
    arguments: (arguments
      (
        [
          (string (string_fragment))
          (undefined)
          (null)
        ]
      )?
      (
        [
          (string (string_fragment) @i18n.namespace)
          (undefined)
          (null)
        ]
      )?
      (
        [
          (string (string_fragment) @i18n.key_prefix)
          (undefined)
          (null)
        ]
      )?
    )
  )
) @i18n.get_t

; t function call
; Matches: t('key'), i18n.t('key'), i18next.t('key'), etc.
(call_expression
  function: [
    (identifier)
    (member_expression)
  ] @i18n.t_func_name
  arguments: (arguments
    (string
      (string_fragment) @i18n.key
    ) @i18n.key_arg
  )
) @i18n.call_t

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
