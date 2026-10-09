-- у нас есть 3 таблицы : sales_all - все строки включая покупателей без айди плюс есть флаг сервиса
-- sales_customers - без пропусков
-- reterns - возвраты, которые удалены из двух предыдущих таблиц 

-- основная задача для скл - это посчитать основные метрики, ответить на вопросы, которые будут информативны для дашборда
-- построить rfm чтобы


-- 1. общая выручка за все время 
select round(sum(revenue)) as revenue  from sales_all;

select round(sum(revenue)) as revenue from sales_all
where is_service = False;

-- 2. выручка по месяцам
select  to_char(invoicedate, 'YYYY-MM') AS month, 
round(sum(revenue)) as revenue from sales_all
group by month
order by month asc;

-- 3. выручка по странам 
select country , round(sum(revenue)) as revenue
from sales_all 
group by country
order by revenue desc 
limit 10;

-- 4. топ 10 товаов 
select description as item, round(sum(revenue)) as revenue
from sales_all 
where is_service = False
group by item
order by revenue desc 
limit 10;

ALTER TABLE sales_all
RENAME COLUMN "customer id" TO customer_id;

ALTER TABLE sales_customers
RENAME COLUMN "customer id" TO customer_id;

-- 5. клиенты и средний чек
select count(distinct customer_id) as customers, round(SUM(quantity * price) / COUNT(DISTINCT invoice)) AS aov
from sales_customers ; 


-- 6. rfm по клиентам (recency, frequency, monetary)
create view v_rfm as
with rfm as (select customer_id, max(invoicedate) as last_order, count(distinct invoice) as frequency, round(SUM(quantity * price)) as monetary
from sales_customers
where is_service = False
group by customer_id
),

rfm_scores as (
select customer_id, ntile(4) over(order by last_order asc) as r_score,
ntile(4) over(order by frequency asc) as f_score,
ntile(4) over(order by monetary asc ) as m_score,
last_order, 
frequency,
monetary
from rfm 
)

select customer_id, last_order, frequency, monetary, r_score, m_score, f_score,
case when r_score >= 3 and f_score >= 3 and m_score >= 3 then 'champion'
when r_score >= 3 and f_score >= 2 and m_score >= 3 then 'loyal'
when r_score >= 3 and f_score <= 2 then 'new'
when r_score <= 2 and f_score >= 2 and m_score >= 3 then 'at risk'
when r_score <= 2 and f_score <=2 and m_score <=2 then 'lost'
else 'others'
end as segments
from rfm_scores
;

drop view v_rfm;


select segments ,count(*) as count_segments
from v_rfm
group by segments
order by count_segments desc;


select customer_id, round(SUM(quantity * price)) as revenue 
from v_rfm 
join sales_customers using(customer_id)
where segments = 'loyal'
group by customer_id
order by revenue desc; 



select segments, round(avg(monetary)) as avg
from v_rfm 
join sales_customers using(customer_id)
group by segments
order by avg desc; 



select customer_id, round(SUM(quantity * price)) as revenue 
from v_rfm 
join sales_customers using(customer_id)
where segments = 'at risk'
group by customer_id
order by revenue desc; 


select description, sum(quantity) as quantity, round(sum(quantity * price)) as revenue
from v_rfm 
join sales_customers using(customer_id)
where segments = 'at risk'
group by description 
order by revenue desc
limit 10;


select description, sum(quantity) as quantity, round(sum(quantity * price)) as revenue
from v_rfm 
join sales_customers using(customer_id)
where segments = 'champion'
group by description 
order by revenue desc
limit 10;

SELECT
    segments,
    COUNT(*) AS customers,
    ROUND((100.0 * COUNT(*) / (SELECT COUNT(*) FROM v_rfm))::numeric, 1) AS pct_customers,
    ROUND(SUM(monetary)::numeric, 0) AS revenue,
    ROUND((100.0 * SUM(monetary) / (SELECT SUM(monetary) FROM v_rfm))::numeric, 1) AS pct_revenue
FROM v_rfm
GROUP BY segments
ORDER BY pct_revenue DESC;


SELECT *
from v_rfm
where segments = 'lost'
order by monetary desc
;

SELECT COUNT(*), COUNT(DISTINCT customer_id) FROM v_rfm;

SELECT SUM(monetary) FROM v_rfm;

select sum(quantity*price)
from sales_customers
where is_service = False;

SELECT segments, ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY monetary))::numeric, 0) AS median_m
FROM v_rfm GROUP BY segments;