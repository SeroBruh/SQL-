-- Перевожу date_new из текстового формата в date
update `transactions_info`
set `date_new` = STR_TO_DATE(`date_new`, '%d/%m/%Y')
where `date_new` is not null and`date_new` != '';

alter table `transactions_info` 
change column `date_new` `date_new` date null default null;


-- список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе без пропусков за указанный годовой период, 
-- средний чек за период с 01.06.2015 по 01.06.2016, 
-- средняя сумма покупок за месяц, 
-- количество всех операций по клиенту за период;
with twelver as (select ID_client 
from transactions_info 
where date_new between '2015-06-01' and '2016-06-01'
group by ID_client
having count(distinct date_format(date_new, '%Y-%m')) =12)
select t.ID_client, count(t.Id_check) as 'Kоличество всех операций по клиенту за период', avg(t.Sum_payment) as 'Cредний чек за период с 01.06.2015 по 01.06.2016',
sum(t.Sum_payment)/count(distinct date_format(date_new,'%Y-%m')) as 'Cредняя сумма покупок за месяц'
from transactions_info t join twelver tt on t.ID_client = tt.ID_client 
where t.date_new between '2015-06-01' and '2016-06-01' 
group by t.ID_client;


-- информацию в разрезе месяцев:

with twelver as (select ID_client 
from transactions_info 
where date_new between '2015-06-01' and '2016-06-01'
group by ID_client
having count(distinct date_format(date_new, '%Y-%m')) =12)
select  t.ID_client, count(t.Id_check) as 'Kоличество всех операций по клиенту за месяц', avg(t.Sum_payment) as 'Cредний чек за месяц',
sum(t.Sum_payment)/count(distinct date_format(date_new,'%Y-%m')) as 'Cредняя сумма покупок за месяц',
date_format(t.date_new,'%Y-%m') as month
from transactions_info t join twelver tt on t.ID_client = tt.ID_client 
where t.date_new between '2015-06-01' and '2016-06-01' 
group by t.ID_client, date_format(t.date_new,'%Y-%m')
order by date_format(t.date_new,'%Y-%m');

-- средняя сумма чека в месяц;

select SUM(Sum_payment)/count(distinct date_format(date_new,'%Y-%m')) as  'Cредняя сумма чека в месяц' from transactions_info;

-- среднее количество операций в месяц;

select count(Id_check)/count(distinct date_format(date_new,'%Y-%m')) as  'Cредняя количество операций в месяц' from transactions_info;

-- среднее количество клиентов, которые совершали операции;

select count(distinct c.Id_client)/count(DISTINCT t.ID_client) as 'Cредняя количество клиентов, которые совершали операции' 
from customer_info c left join transactions_info t on c.Id_client = t.ID_client;

-- долю от общего количества операций за год и долю в месяц от общей суммы операций;

with total_sum as (
select sum(Sum_payment) as total_revenue
from transactions_info 
where date_new between '2015-06-01' and '2016-06-01'
)
select date_format(t.date_new,'%Y-%m') as month,
sum(t.Sum_payment) as 'Cредняя сумма чека в месяц',
round((SUM(t.Sum_payment) / tr.total_revenue)*100,2) as 'Доля в месяц от общей суммы операций'
from transactions_info t
CROSS JOIN total_sum tr
where date_new between '2015-06-01' and '2016-06-01'
group by date_format(t.date_new,'%Y-%m'), tr.total_revenue
order by month ;


-- вывести % соотношение M/F/NA в каждом месяце с их долей затрат;

with monthly_data as (
select date_format(t.date_new,'%Y-%m') month, t.Id_check, t.Sum_payment, 
case when c.Gender = 'M' then 'M'
when c.Gender = 'F' then 'F'
else 'NA'
end as gender_group
from transactions_info t
left join customer_info c on t.ID_client = c.Id_client 
),
monthly_totals as (
select month,
count(distinct Id_check) as operations_montlhy,
Sum(Sum_payment) as revenue_monthly,
count( distinct case when gender_group = 'M' then Id_check end) as m_ops,
count( distinct case when gender_group = 'F' then Id_check end) as f_ops,
count( distinct case when gender_group = 'NA' then Id_check end) as na_ops,
Sum(  case when gender_group = 'M' then Sum_payment else 0 end) as m_rev,
Sum(  case when gender_group = 'F' then Sum_payment else 0 end) as f_rev,
Sum(  case when gender_group = 'NA' then Sum_payment else 0 end) as na_rev
from monthly_data
group by month
)
SELECT 
    month,
    (m_ops / operations_montlhy) * 100  AS 'M соотношение операций (%)',
    (f_ops / operations_montlhy) * 100 AS 'F соотношение операций (%)',
    (na_ops / operations_montlhy) * 100 AS 'NA соотношение операций (%)',
	(m_rev / revenue_monthly) * 100   AS 'M доля затрат (%)',
    (f_rev / revenue_monthly) * 100  AS 'F доля затрат (%)',
    (na_rev / revenue_monthly) * 100 AS 'NA доля затрат (%)'
FROM monthly_totals
ORDER BY month;

-- возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации, с параметрами сумма и количество операций за весь период, и поквартально - средние показатели и %.
-- За весь период
with client_ages as (
select Id_client,
case 
when Age is null then 'NA' 
when Age between 0 and 9 then '0-9'
when Age between 10 and 19 then '10-19'
when Age between 20 and 29 then '20-29'
when Age between 30 and 39 then '30-39'
when Age between 40 and 49 then '40-49'
when Age between 50 and 59 then '50-59'
when Age between 60 and 69 then '60-69'
when Age between 70 and 79 then '70-79'
when Age between 80 and 89 then '80-89'
else '90+'
end as age_group
from customer_info)
select ca.age_group as 'Возрастная группа',
count(distinct t.Id_check) as 'Количество операций',
sum(Sum_payment) as 'Сумма затрат'
from transactions_info t 
left join client_ages ca on t.ID_client = ca.Id_client
group by ca.age_group
order by ca.age_group;

-- Поквартально

with client_ages as (
select Id_client,
case 
when Age is null then 'NA' 
when Age between 0 and 9 then '0-9'
when Age between 10 and 19 then '10-19'
when Age between 20 and 29 then '20-29'
when Age between 30 and 39 then '30-39'
when Age between 40 and 49 then '40-49'
when Age between 50 and 59 then '50-59'
when Age between 60 and 69 then '60-69'
when Age between 70 and 79 then '70-79'
when Age between 80 and 89 then '80-89'
else '90+'
end as age_group
from customer_info),
quarter as (
select concat(year(t.date_new), 'Квартал - ', quarter(t.date_new)) as year_quarter,
ca.age_group, 
t.Id_check,
t.Sum_payment
from transactions_info t
left join client_ages ca on t.ID_client  = ca.Id_client
),
quarter_total as (
select year_quarter,
count(distinct Id_check) as total_quarter_operations,
sum(Sum_payment) as total_quarter_revenue
from quarter
group by year_quarter
)
select q.year_quarter as 'Квартал',
q.age_group as 'Возрастная группа',
count(distinct q.Id_check) as 'Количество операций',
Sum(q.Sum_payment) as 'Сумма',
(count(distinct q.Id_check)/qt.total_quarter_operations) * 100 as 'Доля от операций квартала %',
(Sum(q.Sum_payment)/qt.total_quarter_revenue)*100 as 'Доля от суммы за квартал %',
avg(q.Sum_payment) as 'Средняя сумма',
sum(q.Sum_payment) / count(distinct q.Id_check) as 'Средний чек группы в квартале'
from quarter q 
join quarter_total qt on q.year_quarter = qt.year_quarter
group by q.year_quarter, q.age_group, qt.total_quarter_operations, qt.total_quarter_revenue
order by  q.year_quarter, q.age_group;