import argparse
import os

import duckdb


def orders_report(product=None):
    con = duckdb.connect()
    con.execute("SET TimeZone = 'UTC'")

    bronze = f"s3://{os.environ['LAB_BUCKET_NAME']}/bronze"

    query = f"""
        SELECT
            strftime(date, '%Y-%m') AS month,
            COUNT(*) AS orders,
            SUM(quantity) AS quantity
        FROM read_csv('{bronze}/orders.csv', strict_mode=false)
    """

    if product:
        query += f" WHERE product = '{product}'"

    query += """
        GROUP BY month
        ORDER BY month
    """

    return con.execute(query).fetchall()


def main():
    parser = argparse.ArgumentParser(description="Monthly orders report")
    parser.add_argument("-p", "--product", help="Filter on a product")
    args = parser.parse_args()

    for month, orders, quantity in orders_report(args.product):
        print(f"{month}\t{orders}\t{quantity}")


if __name__ == "__main__":
    main()
