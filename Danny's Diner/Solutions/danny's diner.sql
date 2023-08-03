SELECT * FROM [dbo].[members];
SELECT * FROM [dbo].[menu]
SELECT * FROM [dbo].[sales]


--Case Study Questions

--Q1.What is the total amount each customer spent at the restaurant?

SELECT customer_id, SUM(price) AS total_price_each_customer
FROM [dbo].[sales] s
LEFT JOIN [dbo].[menu] m ON s.product_id = m.product_id
GROUP BY customer_id
ORDER BY 1 ASC;

--Q2.How many days has each customer visited the restaurant?

SELECT 
  customer_id, 
  count(distinct order_date) AS cnt 
FROM 
  [dbo].[sales] s 
  LEFT JOIN [dbo].[menu] m ON s.product_id = m.product_id 
GROUP BY 
  customer_id 
ORDER BY 
  1 ASC;


--Q3.What was the first item from the menu purchased by each customer?

WITH ordered_sales AS (
  SELECT 
    sales.customer_id, 
    sales.order_date, 
    menu.product_name,
    DENSE_RANK() OVER (
      PARTITION BY sales.customer_id 
      ORDER BY sales.order_date) AS rank
  FROM sales
  INNER JOIN menu
    ON sales.product_id = menu.product_id
)

SELECT 
  customer_id, 
  product_name
FROM ordered_sales
WHERE rank = 1
GROUP BY customer_id, product_name;

--Q4.What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT TOP 1
  menu.product_name,
  COUNT(*) AS total_purchases
FROM sales
INNER JOIN menu ON sales.product_id = menu.product_id
GROUP BY menu.product_name
ORDER BY total_purchases DESC

--Q5.Which item was the most popular for each customer?

WITH customer_popularity AS (
  SELECT 
    sales.customer_id, 
    menu.product_name,
    COUNT(*) AS total_purchases,
    RANK() OVER (PARTITION BY sales.customer_id ORDER BY COUNT(*) DESC) AS popularity_rank
  FROM sales
  INNER JOIN menu ON sales.product_id = menu.product_id
  GROUP BY sales.customer_id, menu.product_name
)

SELECT 
  customer_id,
  product_name AS most_popular_item,
  total_purchases AS total_purchases_of_most_popular_item
FROM customer_popularity
WHERE popularity_rank = 1;

--Q6.Which item was purchased first by the customer after they became a member?

--FIRST SOLUTION

WITH first_purchase_after_membership AS (
  SELECT 
    s.customer_id, 
    m.product_name,
    s.order_date,
    ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS purchase_rank
  FROM sales s
  INNER JOIN menu m ON s.product_id = m.product_id
  INNER JOIN members mem ON s.customer_id = mem.customer_id
  WHERE s.order_date >= mem.join_date
)

SELECT 
  customer_id,
  product_name AS first_purchased_item,
  order_date AS first_purchase_date
FROM first_purchase_after_membership
WHERE purchase_rank = 1;


--SECOND SOLUTION

WITH ordered_sales AS (
  SELECT 
    s.customer_id, 
    s.order_date, 
    m.product_name,
    mem.join_date,
    FIRST_VALUE(m.product_name) OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS first_purchased_item
  FROM sales s
  INNER JOIN menu m ON s.product_id = m.product_id
  INNER JOIN members mem ON s.customer_id = mem.customer_id
  WHERE s.order_date >= mem.join_date
)

SELECT 
  customer_id, 
  first_purchased_item
FROM ordered_sales
GROUP BY customer_id, first_purchased_item;

--Q7.Which item was purchased just before the customer became a member?

WITH joined_prior_to_membership AS (
  SELECT 
    members.customer_id, 
    sales.product_id,
    ROW_NUMBER() OVER (
      PARTITION BY members.customer_id
      ORDER BY sales.order_date DESC) AS row_num
  FROM members
  INNER JOIN sales
    ON members.customer_id = sales.customer_id
    AND sales.order_date < members.join_date
)

SELECT 
  j_prior.customer_id, 
  menu.product_name 
FROM joined_prior_to_membership AS j_prior
INNER JOIN menu
  ON j_prior.product_id = menu.product_id
WHERE row_num = 1
ORDER BY customer_id ASC;


--Q8.What is the total items and amount spent for each member before they became a member?

SELECT 
  s.customer_id, 
  COUNT(s.product_id) AS total_items, 
  SUM(m.price) AS total_sales
FROM sales s
INNER JOIN members mem
  ON s.customer_id = mem.customer_id
  AND s.order_date < mem.join_date
INNER JOIN menu m
  ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;

--Q9.If each $1 spent equates to 10 points and sushi
--has a 2x points multiplier - how many points would each customer have?

SELECT 
  s.customer_id, 
  SUM(
    CASE 
      WHEN m.product_id = 1 THEN m.price * 20
      ELSE m.price * 10 
    END
  ) AS total_points
FROM sales s
INNER JOIN menu m
  ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;


--Q10.In the first week after a customer joins the program (including their join date) 
--they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

SELECT 
  s.customer_id, 
  SUM(CASE
    WHEN m.product_name = 'sushi' THEN 2 * 10 * m.price
    WHEN s.order_date BETWEEN mem.join_date AND DATEADD(DAY, 6, mem.join_date) THEN 2 * 10 * m.price
    ELSE 10 * m.price END) AS points
FROM sales s
INNER JOIN members mem ON s.customer_id = mem.customer_id
INNER JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;