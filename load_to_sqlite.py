"""
Helper for Project 2: loads the Olist CSV files into a local SQLite database
so you can run project2_sql_analysis.sql in DB Browser for SQLite, DBeaver, or Python.

Download the dataset from Kaggle: "Brazilian E-Commerce Public Dataset by Olist"
Put all the CSVs in a folder called ./olist/ next to this script.
"""
import os
import sqlite3

import pandas as pd

FILES = {
    "customers": "olist_customers_dataset.csv",
    "orders": "olist_orders_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "products": "olist_products_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
}

conn = sqlite3.connect("olist.db")
for table, fname in FILES.items():
    path = os.path.join("olist", fname)
    df = pd.read_csv(path)
    df.to_sql(table, conn, if_exists="replace", index=False)
    print(f"Loaded {table}: {len(df):,} rows")

# Indexes make the joins in the analysis fast
conn.executescript(
    """
    CREATE INDEX IF NOT EXISTS idx_orders_cust   ON orders(customer_id);
    CREATE INDEX IF NOT EXISTS idx_items_order   ON order_items(order_id);
    CREATE INDEX IF NOT EXISTS idx_items_product ON order_items(product_id);
    CREATE INDEX IF NOT EXISTS idx_pay_order     ON order_payments(order_id);
    CREATE INDEX IF NOT EXISTS idx_rev_order     ON order_reviews(order_id);
    """
)
conn.commit()
conn.close()
print("Done -> olist.db")
