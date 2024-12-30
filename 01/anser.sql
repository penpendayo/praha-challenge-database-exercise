# 1
-- "customer_id","order_count"
-- 61,4
-- 9,3
-- 18,3
-- 32,3
-- 38,3
-- 52,3
-- 60,3
-- 68,3
-- 88,3
-- 91,3
SELECT
  orders.customer_id,
  count(orders.customer_id)
FROM
  orders
WHERE
  YEAR(orders.order_date) = 2023
GROUP BY
  orders.customer_id
HAVING
  count(orders.customer_id) > 2
ORDER BY
  count(orders.customer_id) DESC,
  orders.customer_id;

# 2
# 1にプラスして顧客情報（customersテーブルの全カラム）も取得する。
SELECT
  customers.*,
  count(customers.customer_id)
FROM
  orders
  INNER JOIN customers ON customers.customer_id = orders.customer_id
WHERE
  YEAR(orders.order_date) = 2023
GROUP BY
  orders.customer_id
HAVING
  count(orders.customer_id) > 2
ORDER BY
  count(orders.customer_id) DESC,
  orders.customer_id;

### 3本目
-- 「一番お世話になっている運送会社を教えて欲しい」と頼まれました。過去最も多くの注文（orders）が紐づいた運送会社（shippers）を特定してみてください。
-- 💡 「過去最も多くの注文が紐づいた運送会社」は複数存在するかもしれません。
SELECT
  shipper_id
FROM
  (
    SELECT
      shipper_id,
      COUNT(shipper_id) AS count_shipper_id,
      RANK() OVER (
        ORDER BY
          COUNT(shipper_id) DESC
      ) AS rank_num
    FROM
      orders
    GROUP BY
      shipper_id
  ) _
WHERE
  rank_num = 1;

### 4本目
-- 「重要な市場を把握したい」と頼まれました。売上が高い順番にcountryを並べてみましょう。
-- 売上の定義: 「order_detailsのquantity（個数）」×「productsのprice（単価）」
-- 注文を行った顧客の国（country）を集計すると良いでしょう。
SELECT
  customers.country,
  sum(order_details.quantity * products.price)
FROM
  orders
  INNER JOIN order_details ON order_details.order_id = orders.order_id
  INNER JOIN customers ON customers.customer_id = orders.customer_id
  INNER JOIN products ON products.product_id = order_details.product_id
GROUP BY
  customers.country
ORDER BY
  sum(order_details.quantity * products.price) DESC;

### 5本目
-- 国ごとの売上を年毎に（1月1日~12月31日の間隔で）集計してください。
-- 💡 MySQLで「年だけ」を取得するためには`DATE_FORMAT`を使うと良いでしょう！
SELECT
  customers.country,
  YEAR(orders.order_date),
  sum(order_details.quantity * products.price)
FROM
  orders
  INNER JOIN order_details ON order_details.order_id = orders.order_id
  INNER JOIN customers ON customers.customer_id = orders.customer_id
  INNER JOIN products ON products.product_id = order_details.product_id
GROUP BY
  customers.country,
  YEAR(orders.order_date)
ORDER BY
  customers.country,
  YEAR(orders.order_date);

-- **任意課題（高難易度）**
-- 2023年の国ごとの売上を月毎に集計してください。この際、当該月に売上が無い場合もレコードを出力してください。
-- ※以下、例
-- | country | month | sales |
-- | --- | --- | --- |
-- | Japan | 2023-01 | 100 |
-- | Japan | 2023-02 | NULL |
-- | Japan | 2023-03 | 30 |
-- </aside>

-- 2023-01〜2023-12までの値を取得するCTE
WITH RECURSIVE months AS (
  SELECT
    DATE_FORMAT('2023-01-01', '%Y-%m') AS ym,
    '2023-01-01' AS ym_start_date
  UNION ALL
  SELECT
    DATE_FORMAT(
      DATE_ADD(ym_start_date, INTERVAL 1 MONTH),
      '%Y-%m'
    ),
    DATE_ADD(ym_start_date, INTERVAL 1 MONTH)
  FROM
    months
  WHERE
    ym < '2023-12'
),
-- 売上がある国を取得するCTE
countries AS (
    SELECT DISTINCT country
    FROM orders
    INNER JOIN customers 
      ON customers.customer_id = orders.customer_id
),
-- 国ごとの売上を取得するCTE
sales_by_country AS (
    SELECT
      customers.country AS country,
      DATE_FORMAT(orders.order_date, '%Y-%m') AS month,
      SUM(order_details.quantity * products.price) AS total_sales
    FROM
      orders
      INNER JOIN order_details ON order_details.order_id = orders.order_id
      INNER JOIN customers ON customers.customer_id = orders.customer_id
      INNER JOIN products ON products.product_id = order_details.product_id
    GROUP BY
      customers.country,
      DATE_FORMAT(orders.order_date, '%Y-%m')
)
-- 国別＆月別（売上がない月も含む）の売上を出すSQL
SELECT
  months.ym,
  countries.country,
  sales_by_country.total_sales
FROM
  months
  CROSS JOIN countries
  LEFT JOIN sales_by_country
    ON sales_by_country.country = countries.country
   AND sales_by_country.month = months.ym
ORDER BY
  countries.country,
  months.ym;

### 6本目
-- 「社内の福利厚生の規定が変わったので、年齢が一定以下の社員には、それとわかるようにフラグを立てて欲しい」と頼まれました。
-- employeesテーブルに「junior（若手）」カラム（boolean）を追加して、若手に分類されるemployeesレコードの場合はtrueにしてください。
-- juniorの定義：誕生日が1990年より後
ALTER TABLE
  employees
ADD
  COLUMN junior BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE
  employees
SET
  junior = TRUE
WHERE
  employees.birth_date > DATE('1990-12-31') ### 7本目
  -- 「長くお世話になった運送会社には運送コストを多く払うことになったので、たくさん運送をお願いしている業者を特定して欲しい」と頼まれました。
  -- 「long_relation」カラム（boolean）をshippersテーブルに追加し、long_relationがtrueになるべきshippersレコードを特定して、long_relationをtrueにしてください。
  -- long_relationの定義：これまでに70回以上注文に関わった運送会社（つまり発注を受けて運搬作業を実施した運送会社）
ALTER TABLE
  shippers
ADD
  COLUMN long_relation boolean NOT NULL;

UPDATE
  shippers
SET
  long_relation = TRUE
WHERE
  70 <= (
    SELECT
      count(*)
    FROM
      orders
    WHERE
      orders.shipper_id = shippers.shipper_id
  );

-- ### 8本目
-- 「それぞれの社員が最後に担当した注文と、その日付を取得してほしい」と頼まれました。
-- order_id, employee_id, 最も新しいorder_dateが得られるクエリを書いてください。
-- 💡 同日に複数注文をもらっている場合もあります。その場合は、最小のorder_idだけ表示してください。
SELECT
  tmp.employee_id,
  tmp.order_id,
  tmp.order_date
FROM
  (
    SELECT
      orders.*,
      row_number() over (
        PARTITION by employees.employee_id
        ORDER BY
          orders.order_date DESC,
          orders.shipper_id
      ) AS ranking
    FROM
      employees
      LEFT JOIN orders ON orders.employee_id = employees.employee_id
  ) tmp
WHERE
  tmp.ranking = 1;

-- ### 9本目
-- アプリケーションの要件変更によって、customersのcontact_nameは未設定でも許容することになりました。値としてNULLを許容するようにテーブルの定義を変更してみてください。
-- 次に、customer_id=1のレコードのcontact_nameをNULLにしてください。
-- その後、
-- - contact_nameが存在するユーザを取得するクエリを作成してください。
-- - contact_nameが存在しない（NULLの）ユーザを取得するクエリを変えてください。
-- 💡 もしかすると、contact_nameが存在しないユーザーを取得するクエリを、このように書いた方がいるかもしれません。
-- `SELECT * FROM customers WHERE contact_name = NULL;` 
-- しかし残念ながら、これでは期待した結果は得られません。なぜでしょうか？
ALTER TABLE
  customers
MODIFY
  contact_name VARCHAR(255) NULL;

UPDATE
  customers
SET
  contact_name = NULL
WHERE
  customers.customer_id = 1;

SELECT
  *
FROM
  customers
WHERE
  customers.contact_name IS NOT NULL;

SELECT
  *
FROM
  customers
WHERE
  customers.contact_name IS NULL;

-- ✅️
-- NULL は「値が存在しない、もしくは不明である」という値なので、比較しても「わからん」という結果になるので何も値が帰ってこない。なのでnullと比較したいときはIS NULLという専用の構文を使う必要がある。

-- ### 10本目
-- 従業員が1人、退職してしまいました。employee_id=1の従業員のレコードをemployeesテーブルから削除してください。
-- その後、ordersとemployeesをJOINして、注文と担当者を取得してください。
-- その後、
-- （削除された）emloyee_id=1が担当したordersを表示しないクエリを書いてください。
-- （削除された）emloyee_id=1が担当したordersを表示する（employeesに関する情報はNULLで埋まる）クエリを書いてください
SELECT
  *
FROM
  employees
  INNER JOIN orders ON orders.employee_id = employees.employee_id
ORDER BY
  employees.employee_id
LIMIT
  300;

SELECT
  *
FROM
  employees
  RIGHT JOIN orders ON orders.employee_id = employees.employee_id
ORDER BY
  employees.employee_id
LIMIT
  300;