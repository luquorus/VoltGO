path = r'c:\Users\luquo\2025.1\ĐATN\VoltGO\backend\src\main\java\com\example\evstation\station\infrastructure\jpa\StationQueryRepositoryImpl.java'
with open(path, 'rb') as f:
    raw = f.read()

# Find text block opening (""") - look for the baseQuery assignment
idx = raw.find(b'String baseQuery = ')
if idx == -1:
    print('Not found: "String baseQuery ="')
else:
    # Show the next 100 bytes after this
    print(f'Found at {idx}')
    print(f'Next 200 bytes: {repr(raw[idx:idx+200])}')

# Also check if the file uses the old text block approach
if b'WITH route_line AS' in raw:
    print('Found "WITH route_line AS"')
    idx3 = raw.find(b'WITH route_line AS')
    print(f'Context: {repr(raw[idx3-30:idx3+50])}')
