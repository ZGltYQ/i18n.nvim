; i18next translation function calls
; Matches: t('key'), i18n.t('key'), i18next.t('key')

; getFixedT function call
; Matches: i18n.getFixedT(), i18next.getFixedT()
(variable_declarator
  name: (identifier) @i18n.t_func_name
  value: (call_expression
    function: [
      ; Direct getFixedT() calls
      (identifier) @get_fixed_t_func (#eq? @get_fixed_t_func "getFixedT")
      ; i18n.getFixedT(), i18next.getFixedT()
      (member_expression
        object: (identifier) @_i18n_obj (#match? @_i18n_obj "^(i18n|i18next|translator).*")
        property: (property_identifier) @get_fixed_t_func (#eq? @get_fixed_t_func "getFixedT")
      )
    ]
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
    ; Direct t() calls
    (identifier) @i18n.t_func_name (#match? @i18n.t_func_name "^t$")
    ; i18n.t(), i18next.t(), and similar patterns
    (member_expression
      object: (identifier) @i18n_obj (#match? @i18n_obj "^(i18n|i18next|translator).*")
      property: (property_identifier) @i18n.t_func_name (#eq? @i18n.t_func_name "t")
    )
  ]
  arguments: (arguments
    (string
      (string_fragment) @i18n.key
    ) @i18n.key_arg
  )
) @i18n.call_t

; Template literal support
; Matches: t(`key`), i18n.t(`key`)
(call_expression
  function: [
    ; Direct t() calls with template literals
    (identifier) @_function (#eq? @_function "t")
    ; i18n.t(), i18next.t() with template literals
    (member_expression
      object: (identifier) @_i18n_obj (#match? @_i18n_obj "^(i18n|i18next|translator).*")
      property: (property_identifier) @_prop (#eq? @_prop "t")
    )
  ]
  arguments: (arguments
    (template_string
      (string_fragment) @i18n.key)))

; Object-style translation with key property
; Matches: t({ key: 'translation.key' }), i18n.t({ key: 'translation.key' })
(call_expression
  function: [
    ; Direct t() calls with object argument
    (identifier) @_function (#eq? @_function "t")
    ; i18n.t(), i18next.t() with object argument
    (member_expression
      object: (identifier) @_i18n_obj (#match? @_i18n_obj "^(i18n|i18next|translator).*")
      property: (property_identifier) @_prop (#eq? @_prop "t")
    )
  ]
  arguments: (arguments
    (object
      (pair
        key: (property_identifier) @_prop_name (#eq? @_prop_name "key")
        value: (string
          (string_fragment) @i18n.key)))))

; i18next.exists() method - checks if translation key exists
; Matches: i18n.exists('key'), i18next.exists('key')
(call_expression
  function: (member_expression
    object: (identifier) @_i18n_obj (#match? @_i18n_obj "^(i18n|i18next|translator).*")
    property: (property_identifier) @_method (#eq? @_method "exists")
  )
  arguments: (arguments
    (string
      (string_fragment) @i18n.key
    )
  )
) @i18n.call_exists
