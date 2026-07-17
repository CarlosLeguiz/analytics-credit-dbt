-- Macro para generar la surrogate key de cliente de forma consistente en
-- todos los modelos (dim_customers, fct_payments, fct_applications, etc).
--
-- Por qué está en una macro y no inline en cada modelo:
-- Si mañana cambio la fórmula, solo cambio acá y todos los modelos se actualizan.
-- Sin macro tendría que updatear cada archivo por separado con riesgo de
-- inconsistencia.
--
-- Uso: {{ generate_customer_sk() }} as customer_sk

{% macro generate_customer_sk(customer_id_column='customer_id') %}
    {{ dbt_utils.generate_surrogate_key([customer_id_column]) }}
{% endmacro %}