-- tests/assert_shift_logs_unique.sql

select
    date,
    shift,
    count(*) as row_count
from {{ ref('stg_shift_logs') }}
group by date, shift
having count(*) > 1