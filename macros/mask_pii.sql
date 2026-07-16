{#
  Macro: mask_pii
  Propósito:
    Enmascara valores de columnas PII en ambientes no productivos.
    En prod devuelve el valor original. En dev/qa/ci devuelve un valor
    enmascarado que preserva la forma general del dato sin exponer PII real.

  Uso:
    {{ mask_pii('email', 'email') }} as email,
    {{ mask_pii('phone', 'phone') }} as phone,
    {{ mask_pii('first_name', 'name') }} as first_name

  Argumentos:
    - column_name: nombre de la columna a enmascarar
    - pii_type: tipo de PII, define el patrón de masking
                Valores válidos: 'email', 'phone', 'name', 'birth_date'
#}

{% macro mask_pii(column_name, pii_type) %}

    {% if target.name == 'prod' %}

        {{ column_name }}

    {% else %}

        {% if pii_type == 'email' %}
            concat(substring({{ column_name }}, 1, 2), '***@masked.com')

        {% elif pii_type == 'phone' %}
            concat(substring({{ column_name }}, 1, 4), '****', substring({{ column_name }}, -2))

        {% elif pii_type == 'name' %}
            concat(substring({{ column_name }}, 1, 1), '****')

        {% elif pii_type == 'birth_date' %}
            date_trunc({{ column_name }}, year)

        {% else %}
            '*** MASKED ***'

        {% endif %}

    {% endif %}

{% endmacro %}