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

print("=== TENANTS ===")
res = fetch("https://pqlmomdpuiajhfwwfoqw.supabase.co/rest/v1/tenants?select=*")
print(res)
