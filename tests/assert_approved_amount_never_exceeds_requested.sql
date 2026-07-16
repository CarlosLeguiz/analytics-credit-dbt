-- ============================================================================
-- Test: El monto aprobado nunca puede ser mayor al monto solicitado
-- Regla de negocio: Naranja X puede aprobar el monto pedido o menor,
-- pero nunca más. Si esto pasa, hay un bug de datos upstream (probablemente
-- en el sistema de originacion o en un join incorrecto).
-- Si devuelve 0 filas: el test pasa. Si devuelve alguna: el test falla.
-- ============================================================================

select
    o.origination_id,
    o.application_id,
    o.customer_id,
    a.requested_amount_ars,
    o.approved_amount_ars,
    (o.approved_amount_ars - a.requested_amount_ars) as excess_amount_ars

from {{ ref('fct_originations') }} o
inner join {{ ref('fct_applications') }} a
    on o.application_id = a.application_id

where o.approved_amount_ars > a.requested_amount_ars