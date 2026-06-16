import urllib.request
import json

headers = {
    "apikey": "sb_publishable_cHJmRkHvAl1MPqmKGgQtqA_OHdC81hR",
    "Authorization": "Bearer sb_publishable_cHJmRkHvAl1MPqmKGgQtqA_OHdC81hR"
}

def fetch(url):
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode())
    except Exception as e:
        return f"Error: {e}"

print("=== LATEST COMMERCE ORDER ITEMS ===")
res_items = fetch("https://pqlmomdpuiajhfwwfoqw.supabase.co/rest/v1/commerce_order_items?select=id,order_id,product_id,quantity,inventory_item_id&limit=10&order=id.desc")
print(json.dumps(res_items, indent=2))

print("\n=== LATEST ACCOUNTING ENTRIES ===")
res_entries = fetch("https://pqlmomdpuiajhfwwfoqw.supabase.co/rest/v1/inventory_accounting_entries?select=id,type,commerce_order_item_id,tenant_id,inventory_item_id,quantity,total_cost_amount,status&limit=10&order=id.desc")
print(json.dumps(res_entries, indent=2))
