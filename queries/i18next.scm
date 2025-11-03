; i18next translation function calls
; Matches: t('key'), i18n.t('key'), i18next.t('key')

; getFixedT function call - Direct getFixedT() calls
; Matches: const t = getFixedT()
(variable_declarator
  name: (identifier) @i18n.t_func_name
  value: (call_expression
    function: (identifier) @_func (#eq? @_func "getFixedT")
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

; getFixedT function call - Member expression calls
; Matches: const t = i18n.getFixedT(), const t = i18next.getFixedT()
(variable_declarator
  name: (identifier) @i18n.t_func_name
  value: (call_expression
    function: (member_expression
      object: (identifier) @_i18n_obj (#match? @_i18n_obj "^(i18n|i18next|translator)$")
      property: (property_identifier) @_prop (#eq? @_prop "getFixedT")
    )
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

; t function call - Direct t() calls only
; Matches: t('key')
(call_expression
  function: (identifier) @_function (#eq? @_function "t")
  arguments: (arguments
    (string
      (string_fragment) @i18n.key
    ) @i18n.key_arg
  )
) @i18n.call_t

; t function call - Member expression calls
; Matches: i18n.t('key'), i18next.t('key'), translator.t('key')
(call_expression
  function: (member_expression
    object: (identifier) @_i18n_obj (#match? @_i18n_obj "^(i18n|i18next|translator)$")
    property: (property_identifier) @_prop (#eq? @_prop "t")
  )
  arguments: (arguments
    (string
      (string_fragment) @i18n.key
    ) @i18n.key_arg
  )
) @i18n.call_t

; Template literal support - Direct t() calls
; Matches: t(`key`)
(call_expression
  function: (identifier) @_function (#eq? @_function "t")
  arguments: (arguments
    (template_string
      (string_fragment) @i18n.key)))

; Template literal support - Member expression calls
; Matches: i18n.t(`key`), i18next.t(`key`)
(call_expression
  function: (member_expression
    object: (identifier) @_i18n_obj (#match? @_i18n_obj "^(i18n|i18next|translator)$")
    property: (property_identifier) @_prop (#eq? @_prop "t")
  )
  arguments: (arguments
    (template_string
      (string_fragment) @i18n.key)))

; Object-style translation - Direct t() calls
; Matches: t({ key: 'translation.key' })
(call_expression
  function: (identifier) @_function (#eq? @_function "t")
  arguments: (arguments
    (object
      (pair
        key: (property_identifier) @_prop_name (#eq? @_prop_name "key")
        value: (string
          (string_fragment) @i18n.key)))))

; Object-style translation - Member expression calls
; Matches: i18n.t({ key: 'translation.key' }), i18next.t({ key: 'translation.key' })
(call_expression
  function: (member_expression
    object: (identifier) @_i18n_obj (#match? @_i18n_obj "^(i18n|i18next|translator)$")
    property: (property_identifier) @_prop (#eq? @_prop "t")
  )
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
    object: (identifier) @_i18n_obj (#match? @_i18n_obj "^(i18n|i18next|translator)$")
    property: (property_identifier) @_method (#eq? @_method "exists")
  )
  arguments: (arguments
    (string
      (string_fragment) @i18n.key
    )
  )
) @i18n.call_exists
