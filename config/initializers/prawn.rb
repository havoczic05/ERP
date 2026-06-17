# Prawn's built-in AFM fonts use Windows-1252, which covers the Spanish
# characters (á é í ó ú ñ ¿ ¡) this ERP needs. Silence the generic UTF-8
# warning so it does not flood CI logs; documents are validated by specs.
Prawn::Fonts::AFM.hide_m17n_warning = true
