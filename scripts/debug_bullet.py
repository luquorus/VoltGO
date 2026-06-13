path = r'c:\Users\luquo\2025.1\ĐATN\VoltGO\backend\src\main\java\com\example\evstation\station\infrastructure\jpa\StationQueryRepositoryImpl.java'
with open(path, 'rb') as f:
    raw = f.read()
content = raw.decode('utf-8')

# Find the methods
start = content.find("private String buildRecommendationReason(")
end_end = content.find("private String buildFallbackRecommendationReason(", start)
if end_end == -1:
    print("buildFallbackRecommendationReason not found")
    exit(1)
end_end = content.find("\n    }", end_end + 10)
if end_end == -1:
    print("Closing brace not found")
    exit(1)
end_end += 4

# Get the exact bytes
method_block = content[start:end_end]
print(f"Method block length: {len(method_block)}")
print("First 200 chars:", repr(method_block[:200]))

# Check the bullet character
for i, c in enumerate(method_block):
    if ord(c) > 127:
        print(f"Non-ASCII at {i}: U+{ord(c):04X} = '{c}'")
