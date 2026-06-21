import urllib.request
import re

html = urllib.request.urlopen("http://127.0.0.1:8795/setup").read().decode()

# Find all http URLs in the page
urls = re.findall(r'http://[^\s"\'<>]+', html)
print("All HTTP URLs found:")
for u in urls:
    print(f"  {u}")
