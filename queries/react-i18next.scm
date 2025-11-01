; React i18next patterns
; Matches: useTranslation(), <Trans i18nKey="key" />

; useTranslation hook
; const { t } = useTranslation()
(call_expression
  function: (identifier) @_function (#eq? @_function "useTranslation")
  arguments: (arguments
    (string
      (string_fragment) @i18n.namespace)?))

; Trans component with i18nKey prop
; <Trans i18nKey="key">...</Trans>
(jsx_opening_element
  name: (identifier) @_component (#eq? @_component "Trans")
  attributes: (jsx_attributes
    (jsx_attribute
      (property_identifier) @_attr (#eq? @_attr "i18nKey")
      (string
        (string_fragment) @i18n.key))))

; Trans component with i18nKey in curly braces
; <Trans i18nKey={"key"}>...</Trans>
(jsx_opening_element
  name: (identifier) @_component (#eq? @_component "Trans")
  attributes: (jsx_attributes
    (jsx_attribute
      (property_identifier) @_attr (#eq? @_attr "i18nKey")
      (jsx_expression
        (string
          (string_fragment) @i18n.key)))))

; Trans component self-closing
; <Trans i18nKey="key" />
(jsx_self_closing_element
  name: (identifier) @_component (#eq? @_component "Trans")
  attributes: (jsx_attributes
    (jsx_attribute
      (property_identifier) @_attr (#eq? @_attr "i18nKey")
      (string
        (string_fragment) @i18n.key))))

; Trans component with i18nKey in curly braces (self-closing)
(jsx_self_closing_element
  name: (identifier) @_component (#eq? @_component "Trans")
  attributes: (jsx_attributes
    (jsx_attribute
      (property_identifier) @_attr (#eq? @_attr "i18nKey")
      (jsx_expression
        (string
          (string_fragment) @i18n.key)))))

; Translation component (alternate name)
(jsx_self_closing_element
  name: (identifier) @_component (#eq? @_component "Translation")
  attributes: (jsx_attributes
    (jsx_attribute
      (property_identifier) @_attr (#eq? @_attr "i18nKey")
      (string
        (string_fragment) @i18n.key))))
