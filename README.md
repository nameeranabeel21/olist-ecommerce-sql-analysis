# Olist E-commerce: SQL Business Analysis

**Tools:** SQL (SQLite), Python (data loading), DB Browser for SQLite

## 1. Business problem
Olist is a Brazilian online marketplace. As an analyst, I asked: **where does revenue come from, who are the customers, and where does the business have operational or retention problems?**

## 2. Data
- Source: [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/) (Kaggle), a relational dataset of real orders from 2016 to 2018.
- Six tables used: `customers`, `orders`, `order_items`, `products`, `order_payments`, `order_reviews`.
- Currency is Brazilian reais (R$). Revenue means item price only, and does not include shipping.
- Revenue queries use delivered orders only.

## 3. Approach
1. Loaded the CSV files into a SQLite database with `load_to_sqlite.py` and added indexes so joins run fast.
2. Wrote SQL queries in `project2_sql_analysis.sql` using joins, CTEs, window functions (`LAG`, `SUM() OVER`) and conditional aggregation.
3. Checked each result for data quality problems before drawing conclusions.

## 4. Key findings

### Revenue grew about 8x in a year, peaked at Black Friday, then flattened
- Monthly revenue rose from R$ 111.8K (Jan 2017) to R$ 924.6K (Jan 2018).
- **November 2017 was the peak month: R$ 987.8K, up 52.4% on October**, most likely due to Black Friday. December then fell 26.5%.
- In 2018 revenue stayed between R$ 826K and R$ 978K a month. It dropped 12.4% in June 2018 and stayed lower in July and August.
- Data note: late 2016 has almost no data (as few as 1 order in a month, and one month missing), so growth percentages for early months are meaningless and were ignored.

### Revenue is spread across many categories, with no single dependency
- Top category: **health and beauty** (R$ 1.26M, 9.3% of revenue), followed by **watches and gifts** (R$ 1.21M, 8.9%) and **bed, bath and table** (R$ 1.04M, 7.6%).
- The top 3 categories make up 25.8% of revenue. The top 10 make up 62.4%.
- Watches and gifts earns almost as much as health and beauty from 38% fewer items sold, because its average item price is higher (about R$ 201 vs R$ 130).
- Bed, bath and table sells the most items (11,115) but at a lower price (about R$ 93).

### Almost nobody comes back
- Of 96,096 customers, only **2,997 (3.12%) ordered more than once**.
- The top 10 customers by spend each placed a single order (except one with two). The biggest single customer spent R$ 13,440 in one order.
- Growth comes from acquiring new customers, not from loyalty.

### Delivery is much slower outside the south-east
- São Paulo (SP) averages **8.8 days** from purchase to delivery and 5.9% of its orders arrive late. It is also the biggest market, with 40,494 delivered orders.
- The slowest states are Amazonas (26.4 days), Alagoas (24.5) and Pará (23.8), roughly 3x slower than SP.
- **Alagoas has the highest late rate (23.9%)**, followed by Maranhão (19.7%). Rio de Janeiro, a large market, is late on 13.5% of its 12,350 orders.
- Amazonas is slow but late on only 4.1% of orders, which suggests its delivery estimates are set conservatively.

### Credit card dominates payments
- Credit card is used for **73.9%** of payments (average R$ 163), boleto (bank slip) for 19.0% (average R$ 145), vouchers for 5.6% and debit card for 1.5%.
- Voucher payments are small (average R$ 66).

## 5. Recommendations
1. **Plan for the November spike.** Black Friday drove the single biggest revenue jump, so stock, support and delivery capacity should be ready for it each year.
2. **Invest in repeat purchases.** With a 3% repeat rate, even a small improvement (follow-up emails, vouchers on a second order) would add revenue without new advertising costs.
3. **Fix delivery in the worst states.** Alagoas and Maranhão have both slow and frequently late deliveries. Better carrier partnerships or more realistic delivery estimates would help.
4. **Promote high-ticket categories.** Watches and gifts earns as much as bigger categories from far fewer sales.

## 6. Limitations and next steps
- Revenue excludes shipping fees, and only delivered orders were counted in the monthly analysis.
- The dataset covers 2016 to 2018 only, so conclusions about seasonality rely on a single Black Friday.
- Next: test whether late delivery lowers review scores, and segment customers by recency, frequency and spend.

## 7. How to run
1. Download the dataset from Kaggle and place the CSV files in a folder named `olist`.
2. Run `python load_to_sqlite.py` to create `olist.db`.
3. Open `olist.db` in [DB Browser for SQLite](https://sqlitebrowser.org/) and run the queries from `project2_sql_analysis.sql` one at a time.
